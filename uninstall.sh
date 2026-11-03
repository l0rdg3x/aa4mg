#!/bin/bash

pm uninstall-system-updates com.google.android.projection.gearhead
[ "$(cat "$(dirname "$0")/velvet_mode" 2>/dev/null)" = real ] && pm uninstall-system-updates com.google.android.googlequicksearchbox
