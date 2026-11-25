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

# Preserve installed client data only when the new package has no version of
# its own. The client checks completeness before using preserved files.
for kind in things sounds; do
  source_root="$app/Contents/Resources/data/$kind"
  dest_root="$new/Contents/Resources/data/$kind"
  [ -d "$source_root" ] && [ ! -L "$source_root" ] || continue
  mkdir -p "$dest_root"
  for source_version in "$source_root"/*; do
    [ -d "$source_version" ] && [ ! -L "$source_version" ] || continue
    version=${source_version##*/}
    case "$version" in *[!0-9]*|'') continue ;; esac
    [ ! -e "$dest_root/$version" ] && [ ! -L "$dest_root/$version" ] || continue
    cp -R "$source_version" "$dest_root/$version"
  done
done

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
