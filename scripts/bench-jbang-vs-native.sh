#!/usr/bin/env bash
set -euo pipefail

RELEASE_URL="https://github.com/wanling0000/jabref/releases/download/jabkit-native-preview/jabkit-native-linux-x86_64.tar.gz"
NATIVE_DIR="/tmp/jabkit-native-release"

rm -rf "$NATIVE_DIR"
mkdir -p "$NATIVE_DIR"

curl -L "$RELEASE_URL" | tar -xzf - -C "$NATIVE_DIR"

chmod +x "$NATIVE_DIR/jabkit"
"$NATIVE_DIR/jabkit" --help >/dev/null

jbang app install --fresh --force jabkit@jabref
export PATH="$HOME/.jbang/bin:$PATH"

jabkit --help >/dev/null

hyperfine --warmup 10 --min-runs 30 \
  -n "JBang (jabkit@jabref)" "jabkit --help >/dev/null" \
  -n "native image (release)" "'$NATIVE_DIR/jabkit' --help >/dev/null" \
  --export-markdown jbang-vs-native.md \
  --export-json jbang-vs-native.json
