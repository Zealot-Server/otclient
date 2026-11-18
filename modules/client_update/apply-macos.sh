#!/bin/sh
set -eu

pid=$1
archive=$2
workdir=${3%/}
expected=$4
case "$workdir" in
  */Contents/Resources) app=${workdir%/Contents/Resources} ;;
  *) exit 1 ;;
esac
parent=$(dirname "$app")
log=$(dirname "$archive")/install.log
exec >>"$log" 2>&1

attempt=0
while kill -0 "$pid" 2>/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 120 ] || exit 1
  sleep 1
done

actual=$(shasum -a 256 "$archive" | awk '{print $1}')
[ "$actual" = "$expected" ] || exit 1
stage=$(mktemp -d "$parent/.zealot-update.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto -x -k "$archive" "$stage"
new="$stage/Zealot Client.app"
[ -d "$new/Contents/Resources/modules" ] || exit 1
[ -x "$new/Contents/MacOS/Zealot Client" ] || exit 1
[ -d "$app" ] && [ ! -L "$app" ] || exit 1

backup="$app.previous.$(date +%s)"
mv "$app" "$backup"
if ! mv "$new" "$app"; then
  mv "$backup" "$app"
  exit 1
fi
if ! open "$app"; then
  mv "$app" "$stage/failed-app"
  mv "$backup" "$app"
  open "$app" || true
  exit 1
fi
