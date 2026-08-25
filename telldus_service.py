#!/usr/bin/env python3
"""Store Fineoffset-TelldusProove readings from rtl_433 for a KDE widget."""

import argparse
import json
import logging
import os
import signal
import sqlite3
import subprocess
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

MODEL = "Fineoffset-TelldusProove"
DEFAULT_DB = Path.home() / ".local/state/telldus-rtl/readings.db"
DEFAULT_COMMAND = ["rtl_433", "-F", "json"]


class ReadingStore:
    def __init__(self, database: Path) -> None:
        database.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(database, check_same_thread=False)
        self.lock = threading.Lock()
        with self.connection:
            self.connection.execute(
                """CREATE TABLE IF NOT EXISTS readings (
                    id INTEGER PRIMARY KEY,
                    device_id TEXT NOT NULL,
                    captured_at TEXT NOT NULL,
                    temperature_c REAL NOT NULL,
                    humidity REAL
                )"""
            )
            self.connection.execute(
                "CREATE INDEX IF NOT EXISTS readings_captured_at ON readings(captured_at)"
            )

    def add(self, payload: dict[str, Any]) -> bool:
        if payload.get("model") != MODEL or not isinstance(payload.get("temperature_C"), (int, float)):
            return False
        captured_at = payload.get("time")
        if not isinstance(captured_at, str):
            captured_at = datetime.now(timezone.utc).isoformat()
        device_id = str(payload.get("id", "unknown"))
        humidity = payload.get("humidity")
        if not isinstance(humidity, (int, float)):
            humidity = None
        with self.lock, self.connection:
            self.connection.execute(
                "INSERT INTO readings(device_id, captured_at, temperature_c, humidity) VALUES (?, ?, ?, ?)",
                (device_id, captured_at, float(payload["temperature_C"]), humidity),
            )
        return True

    def latest(self, limit: int = 50) -> list[dict[str, Any]]:
        with self.lock:
            rows = self.connection.execute(
                """SELECT device_id, captured_at, temperature_c, humidity
                   FROM readings ORDER BY captured_at DESC, id DESC LIMIT ?""",
                (max(1, min(limit, 500)),),
            ).fetchall()
        return [
            {"id": row[0], "time": row[1], "temperature_C": row[2], "humidity": row[3]}
            for row in rows
        ]


class ApiHandler(BaseHTTPRequestHandler):
    store: ReadingStore

    def do_GET(self) -> None:  # noqa: N802
        if self.path.split("?", 1)[0] != "/api/readings":
            self.send_error(404)
            return
        body = json.dumps({"model": MODEL, "readings": self.store.latest()}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: Any) -> None:
        logging.debug(format, *args)


def consume(lines: Any, store: ReadingStore) -> int:
    stored = 0
    for line in lines:
        try:
            payload = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(payload, dict) and store.add(payload):
            stored += 1
            logging.info("stored device %s: %.1f C", payload.get("id", "unknown"), payload["temperature_C"])
    return stored


def run(args: argparse.Namespace) -> None:
    store = ReadingStore(args.db)
    if args.input_file:
        with args.input_file.open(encoding="utf-8") as input_stream:
            stored = consume(input_stream, store)
        logging.info("stored %d matching readings", stored)
        if args.once:
            return

    server = ThreadingHTTPServer(("127.0.0.1", args.port), ApiHandler)
    ApiHandler.store = store
    stop = threading.Event()
    process_holder: list[subprocess.Popen[str] | None] = [None]

    def shutdown(*_: Any) -> None:
        if not stop.is_set():
            stop.set()
            process = process_holder[0]
            if process is not None and process.poll() is None:
                process.terminate()
            threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    logging.info("API listening at http://127.0.0.1:%d/api/readings", server.server_port)

    def read_rtl() -> None:
        while not stop.is_set():
            logging.info("starting: %s", " ".join(args.command))
            process = subprocess.Popen(args.command, stdout=subprocess.PIPE, text=True, bufsize=1)
            process_holder[0] = process
            assert process.stdout is not None
            consume(process.stdout, store)
            process_holder[0] = None
            if not stop.is_set():
                logging.warning("rtl_433 exited; restarting in 5 seconds")
                stop.wait(5)

    reader = threading.Thread(target=read_rtl, name="rtl-433-reader", daemon=True)
    reader.start()
    server.serve_forever()
    stop.set()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=Path(os.environ.get("TELLDUS_DB", DEFAULT_DB)))
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--input-file", type=Path, help="Read JSON lines from a file instead of rtl_433")
    parser.add_argument("--once", action="store_true", help="Exit after reading --input-file")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="rtl_433 command, after --")
    args = parser.parse_args()
    args.command = args.command or DEFAULT_COMMAND
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    return args


if __name__ == "__main__":
    run(parse_args())