#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.config/telldus-rtl"
install -m 755 "$project_dir/telldus_service.py" "$HOME/.local/bin/telldus-rtl"
install -m 644 "$project_dir/config.ini" "$HOME/.config/telldus-rtl/config.ini"
install -m 644 "$project_dir/telldus-rtl.service" "$HOME/.config/systemd/user/telldus-rtl.service"
systemctl --user daemon-reload
systemctl --user enable --now telldus-rtl.service
printf '%s\n' "Service started. API: http://127.0.0.1:8765/api/readings"