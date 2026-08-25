# Telldus Temperature

This project reads `rtl_433 -F json`, keeps only `Fineoffset-TelldusProove` messages, stores them in SQLite, and provides the latest readings to a KDE Plasma widget over localhost.

## Install the service

Make sure `rtl_433` is installed and works for your SDR, then run:

```sh
./install-service.sh
systemctl --user status telldus-rtl.service
```

The service stores its database at `~/.local/state/telldus-rtl/readings.db` and listens only on `127.0.0.1:8765`.

To use a different rtl_433 command, edit the `ExecStart` command in the installed unit, for example:

```ini
ExecStart=%h/.local/bin/telldus-rtl -- -f 868.3M -F json
```

Reload after changing it with `systemctl --user daemon-reload && systemctl --user restart telldus-rtl`.

## Install the Plasma widget

```sh
./install-widget.sh
```

Add **Telldus Temperature** from the Plasma widget chooser. It refreshes every 30 seconds and displays each sensor ID, temperature, and humidity when available.

## Test without an SDR

The supplied capture can exercise the filter and database parser:

```sh
python3 telldus_service.py --input-file app.txt --once --db /tmp/telldus-test.db
```

The two Fineoffset readings are stored; the Nexus-TH reading is ignored.