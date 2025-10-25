#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/usr/local/lib/ddFast"

show_help() {
  cat <<EOF
ddFast - a faster version of dd meant strictly for iso flashing

usage:
  sudo ddfast <image.iso> <target_disk>

example:
  sudo ddfast ~/Downloads/os.iso sdX

options:
  -h, --help     show this help message and exit

notes:
   target_disk must be /dev/sdX (x is a placeholder)
   all data on the target drive will be erased
   requires root privileges (use sudo)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "run as root (sudo ddfast ...)"
  exit 1
fi

SRC="${1:-}"
DST="${2:-}"

if [[ -z "$SRC" || -z "$DST" ]]; then
  show_help
  exit 1
fi


[[ "$DST" != /dev/* ]] && DST="/dev/$DST"


[[ -f "$SRC" ]] || { echo "file not found: $SRC"; exit 1; }


[[ -b "$DST" ]] || { echo "target not found or invalid: $DST"; exit 1; }


case "$DST" in
  /dev/sda|/dev/nvme0n1|/dev/vda)
    echo "refusing to write to critical system disk $DST"
    exit 1
    ;;
esac

SRC_SIZE=$(stat -c%s "$SRC")
SRC_H=$(numfmt --to=iec-i --suffix=B "$SRC_SIZE" 2>/dev/null || echo "$SRC_SIZE bytes")
DST_SIZE=$(blockdev --getsize64 "$DST" 2>/dev/null || echo 0)
DST_H=$(numfmt --to=iec-i --suffix=B "$DST_SIZE" 2>/dev/null || echo "$DST_SIZE bytes")

echo "Welcome to ddFast!"
echo "source: $SRC ($SRC_H)"
echo "target: $DST ($DST_H)"
echo

read -r -p "this will erase ALL data on $DST — type YES to continue: " CONF
[[ "$CONF" == "YES" ]] || { echo "aborted."; exit 1; }


for p in $(lsblk -ln -o NAME "$DST" | grep -v "$(basename "$DST")"); do
  umount "/dev/$p" 2>/dev/null || true
done

sync


if command -v pv >/dev/null 2>&1; then
  echo "using pv for progress..."
  pv -tpreb "$SRC" | dd of="$DST" bs=4M iflag=fullblock conv=fsync oflag=direct status=none
else
  echo "using dd with status=progress..."
  dd if="$SRC" of="$DST" bs=4M iflag=fullblock conv=fsync oflag=direct status=progress
fi

sync
echo
echo "done! wrote $SRC → $DST"
echo
echo "────────────────────────────────────────────"
echo " thank you for using ddFast"
echo " made by lucysgutz"
echo " https://lucys.space/"
echo "────────────────────────────────────────────"
