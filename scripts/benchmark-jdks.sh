#!/usr/bin/env bash
set -euo pipefail

JABREF_DIR="${JABREF_DIR:-$HOME/jabref}"
JDK_LIST="${JDK_LIST:-/tmp/jabref-java25-jdks.txt}"
COMMAND_DIR="${COMMAND_DIR:-/tmp/jabref-jdk-benchmark-commands}"
RESULT_PREFIX="${RESULT_PREFIX:-all-jdks-clean}"

JAR="$(ls "$JABREF_DIR"/jabkit/build/libs/jabkit-*-all.jar 2>/dev/null | head -1)"
NATIVE="$JABREF_DIR/jabkit/build/native/nativeCompile/jabkit"

if [ ! -f "$JDK_LIST" ]; then
  echo "Missing $JDK_LIST. Run install-jdks.sh first."
  exit 1
fi

if [ -z "$JAR" ] || [ ! -f "$JAR" ]; then
  echo "Missing JabKit fat jar in $JABREF_DIR/jabkit/build/libs."
  echo "Run ./gradlew :jabkit:shadowJar in the JabRef repository first."
  exit 1
fi

rm -rf "$COMMAND_DIR"
mkdir -p "$COMMAND_DIR"

ARGS=()

while read -r version; do
  safe_name="${version//[^A-Za-z0-9_.-]/_}"
  command_file="$COMMAND_DIR/$safe_name.sh"

  {
    echo "#!/usr/bin/env bash"
    echo "set -euo pipefail"
    mise env "java@$version"
    echo "java -jar '$JAR' --help >/dev/null"
  } > "$command_file"

  chmod +x "$command_file"

  ARGS+=(
    -n "$version"
    "$command_file"
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
  --export-markdown "$RESULT_PREFIX.md" \
  --export-json "$RESULT_PREFIX.json" \
  "${ARGS[@]}"
