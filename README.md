# Telldus Temperature

This project reads `rtl_433 -F json`, keeps only `Fineoffset-TelldusProove` messages, stores them in SQLite, and provides the latest readings to a KDE Plasma widget over localhost.

## Install the service

Make sure `rtl_433` is installed and works for your SDR, then run:

```sh
./install-service.sh
systemctl --user status telldus-rtl.service
```

The service stores its database at `~/.local/state/telldus-rtl/readings.db` and listens only on `127.0.0.1:8765`.
The default schedule is configured in `config.ini`: one 10-second capture every 30 minutes. The service installer copies it to `~/.config/telldus-rtl/config.ini`; edit `interval_minutes` there to change the schedule.

To use a different rtl_433 command, edit the `ExecStart` command in the installed unit, for example:

```ini
ExecStart=%h/.local/bin/telldus-rtl -- -f 868.3M -F json
```

Reload after changing it with `systemctl --user daemon-reload && systemctl --user restart telldus-rtl`.

## Install the Plasma widget

```sh
./install-widget.sh
```

Add **Telldus Temperature** from the Plasma widget chooser. It refreshes every 30 minutes and displays only Air (ID 231) and Water (ID 232).

## Test without an SDR

The supplied capture can exercise the filter and database parser:

```sh
python3 telldus_service.py --input-file app.txt --once --db /tmp/telldus-test.db
```

The two Fineoffset readings are stored; the Nexus-TH reading is ignored.