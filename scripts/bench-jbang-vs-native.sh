#!/usr/bin/env bash
# Benchmarks the official JabKit distributions from builds.jabref.org against JBang.
#
# All three downloaded artifacts come from the same CI build of JabRef main, so they share
# one commit (recorded in env.txt). JBang resolves jabkit@jabref on its own, see README.
#
# Env vars:
#   BUILD_URL   builds.jabref.org folder with the artifacts (default: main, linux-amd64)
#   WORK_DIR    scratch dir for downloads and the isolated JBang home (wiped on start)
#   OUT_DIR     where results land (default: results/distribution-<date>)
set -euo pipefail

BUILD_URL="${BUILD_URL:-https://builds.jabref.org/main/linux-amd64/tools}"
WORK_DIR="${WORK_DIR:-/tmp/jabkit-dist-bench}"
OUT_DIR="${OUT_DIR:-results/distribution-$(date +%F)}"

NATIVE_TGZ=jabkit-native_linux.tar.gz
PORTABLE_TGZ=jabkit-portable_linux.tar.gz

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{native,portable} "$OUT_DIR"

echo "Downloading artifacts from $BUILD_URL"
curl -fsSL "$BUILD_URL/$NATIVE_TGZ" -o "$WORK_DIR/$NATIVE_TGZ"
curl -fsSL "$BUILD_URL/$PORTABLE_TGZ" -o "$WORK_DIR/$PORTABLE_TGZ"
JAR_NAME="$(curl -fsSL "$BUILD_URL/" | grep -oE 'jabkit-[0-9][^"/]*-all\.jar' | head -1)"
curl -fsSL "$BUILD_URL/$JAR_NAME" -o "$WORK_DIR/$JAR_NAME"

tar -xzf "$WORK_DIR/$NATIVE_TGZ" -C "$WORK_DIR/native"
tar -xzf "$WORK_DIR/$PORTABLE_TGZ" -C "$WORK_DIR/portable"

NATIVE="$WORK_DIR/native/jabkit/jabkit"
PORTABLE="$WORK_DIR/portable/jabkit/bin/jabkit"
JAR="$WORK_DIR/$JAR_NAME"

# Isolated JBang home, so its download footprint can be measured from empty.
export JBANG_DIR="$WORK_DIR/jbang"
jbang app install --force jabkit@jabref
JBANG_JABKIT="$JBANG_DIR/bin/jabkit"

# Fail early if any variant does not run at all.
"$NATIVE" --help >/dev/null
"$PORTABLE" --help >/dev/null
"$JBANG_JABKIT" --help >/dev/null

{
  echo "date:          $(date -Iseconds)"
  echo "build url:     $BUILD_URL"
  echo "jabkit build:  $(unzip -p "$JAR" build.properties | grep '^version=' | cut -d= -f2)"
  echo "kernel:        $(uname -srm)"
  echo "cpu:           $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs) ($(nproc) vCPUs)"
  echo "memory:        $(free -h | awk '/^Mem:/ {print $2}')"
  echo "virtualized:   $(systemd-detect-virt 2>/dev/null || echo unknown)"
  echo "hyperfine:     $(hyperfine --version)"
  echo "jbang:         $(jbang version 2>&1 | tail -1)"
  if command -v java >/dev/null; then
    echo "system java:   $(java -version 2>&1 | head -1)"
  else
    echo "system java:   none"
  fi
} | tee "$OUT_DIR/env.txt"

size() { du -sh --apparent-size "$1" | cut -f1; }
{
  echo "| Variant | Download | On disk |"
  echo "|:---|---:|---:|"
  echo "| Native image | $(size "$WORK_DIR/$NATIVE_TGZ") | $(size "$WORK_DIR/native") |"
  echo "| jpackage portable (bundled runtime) | $(size "$WORK_DIR/$PORTABLE_TGZ") | $(size "$WORK_DIR/portable") |"
  echo "| Fat jar (needs a JDK) | $(size "$JAR") | $(size "$JAR") |"
  echo "| JBang home after install | - | $(size "$JBANG_DIR") |"
} | tee "$OUT_DIR/sizes.md"

ARGS=(
  -n "native image" "'$NATIVE' --help >/dev/null"
  -n "jpackage portable" "'$PORTABLE' --help >/dev/null"
  -n "JBang (jabkit@jabref)" "'$JBANG_JABKIT' --help >/dev/null"
)
if command -v java >/dev/null; then
  ARGS+=(-n "java -jar (system JDK)" "java -jar '$JAR' --help >/dev/null")
fi

hyperfine --warmup 10 --min-runs 30 \
  --export-markdown "$OUT_DIR/startup.md" \
  --export-json "$OUT_DIR/startup.json" \
  "${ARGS[@]}"
