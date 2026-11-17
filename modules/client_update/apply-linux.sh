#!/bin/sh
set -eu

pid=$1
archive=$2
target=${3%/}
expected=$4
parent=$(dirname "$target")
log=$(dirname "$archive")/install.log
exec >>"$log" 2>&1

attempt=0
while kill -0 "$pid" 2>/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 120 ] || exit 1
  sleep 1
done

actual=$(sha256sum "$archive" | awk '{print $1}')
[ "$actual" = "$expected" ] || exit 1
stage=$(mktemp -d "$parent/.zealot-update.XXXXXX")
trap 'rm -rf "$stage"' EXIT
tar -xzf "$archive" -C "$stage" --no-same-owner
new="$stage/$(tar -tzf "$archive" | head -1 | cut -d/ -f1)"
[ -x "$new/zealot-client" ] || exit 1
[ -f "$new/init.lua" ] || exit 1
[ -d "$target" ] && [ ! -L "$target" ] || exit 1

backup="$target.previous.$(date +%s)"
mv "$target" "$backup"
if ! mv "$new" "$target"; then
  mv "$backup" "$target"
  exit 1
fi
"$target/run-zealot-client.sh" >/dev/null 2>&1 &
