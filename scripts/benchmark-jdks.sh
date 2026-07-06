#!/usr/bin/env bash
set -euo pipefail

JDK_LIST=/tmp/jabref-java25-jdks.txt
JAR="$(ls jabkit/build/libs/jabkit-*-all.jar | head -1)"
NATIVE="jabkit/build/native/nativeCompile/jabkit"

if [ ! -f "$JDK_LIST" ]; then
  echo "Missing $JDK_LIST. Run ./install-jdks.sh first."
  exit 1
fi

if [ ! -f "$JAR" ]; then
  echo "Missing JabKit fat jar. Run ./gradlew :jabkit:shadowJar first."
  exit 1
fi

ARGS=()

while read -r version; do
  ARGS+=(
    -n "$version"
    "mise exec java@$version -- java -jar '$JAR' --help >/dev/null"
  )
done < "$JDK_LIST"

if [ -x "$NATIVE" ]; then
  ARGS+=(
    -n "native-image"
    "'$NATIVE' --help >/dev/null"
  )
else
  echo "Native image not found at $NATIVE. Skipping native-image benchmark."
fi

hyperfine \
  --warmup 10 \
  --min-runs 30 \
  --export-markdown all-jdks-clean.md \
  --export-json all-jdks-clean.json \
  "${ARGS[@]}"
