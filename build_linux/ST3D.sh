#!/bin/sh
printf '\033c\033]0;%s\a' ST3
base_path="$(dirname "$(realpath "$0")")"
"$base_path/ST3D.x86_64" "$@"
