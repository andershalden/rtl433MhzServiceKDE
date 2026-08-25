#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
kpackagetool6 --type Plasma/Applet --install "$project_dir/widget"
printf '%s\n' "Widget installed. Add 'Telldus Temperature' from the Plasma widget chooser."