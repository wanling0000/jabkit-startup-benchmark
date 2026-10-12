#!/usr/bin/env bash
# JDK sweep for machines without room for every JDK at once.
#
# Installs the latest Java 25 build of every mise distribution in batches, benchmarks each
# batch together with the native image as an anchor, then uninstalls the batch before the
# next one. The native image runs in every batch, so batches can be compared through it.
#
# Env vars:
#   JAR         JabKit fat jar (required), e.g. from bench-jbang-vs-native.sh
#   NATIVE      JabKit native image (required)
#   BATCH_SIZE  JDKs per batch (default 4)
#   OUT_DIR     where results land (default: results/runtime-sweep-batched-<date>)
set -euo pipefail

: "${JAR:?Set JAR to the JabKit fat jar}"
: "${NATIVE:?Set NATIVE to the JabKit native image}"
BATCH_SIZE="${BATCH_SIZE:-4}"
OUT_DIR="${OUT_DIR:-results/runtime-sweep-batched-$(date +%F)}"

mkdir -p "$OUT_DIR"
"$NATIVE" --help >/dev/null

# Same selection as install-jdks.sh: latest Java 25 build per distribution, no JavaFX bundles.
REMOTE="$(mise ls-remote java)"
JDKS=()
for distro in $(echo "$REMOTE" \
    | grep -E '(^|-)25[.-]' | grep -v javafx | grep -vE '^25[.-]' \
    | sed -E 's/-25[.-].*//' | sort -u); do
  JDKS+=("$(echo "$REMOTE" | grep -E "^${distro}-25[.-]" | grep -v javafx | tail -1)")
done
printf '%s\n' "${JDKS[@]}" > "$OUT_DIR/jdks-planned.txt"
echo "Planned ${#JDKS[@]} JDKs in batches of $BATCH_SIZE"

: > "$OUT_DIR/jdks-failed.txt"
batch=0
for ((i = 0; i < ${#JDKS[@]}; i += BATCH_SIZE)); do
  batch=$((batch + 1))
  echo
  echo "== Batch $batch: $(df -h / | awk 'NR == 2 {print $4}') free"

  ARGS=(-n "native-image" "'$NATIVE' --help >/dev/null")
  INSTALLED_HERE=()
  for version in "${JDKS[@]:i:BATCH_SIZE}"; do
    preinstalled=false
    mise where "java@$version" >/dev/null 2>&1 && preinstalled=true

    install_ok=true
    mise install "java@$version" >/dev/null 2>&1 || install_ok=false
    # The downloaded archive is no longer needed once extracted; drop it to save space.
    mise cache clear >/dev/null 2>&1 || true
    if ! $install_ok; then
      echo "FAILED to install $version" | tee -a "$OUT_DIR/jdks-failed.txt"
      continue
    fi
    $preinstalled || INSTALLED_HERE+=("$version")

    java="$(mise where "java@$version")/bin/java"
    if ! "$java" -jar "$JAR" --help >/dev/null 2>&1; then
      echo "FAILED to run JabKit on $version" | tee -a "$OUT_DIR/jdks-failed.txt"
      continue
    fi
    ARGS+=(-n "$version" "'$java' -jar '$JAR' --help >/dev/null")
  done

  hyperfine --warmup 10 --min-runs 30 \
    --export-markdown "$OUT_DIR/batch-$batch.md" \
    --export-json "$OUT_DIR/batch-$batch.json" \
    "${ARGS[@]}"

  # Only remove what this script installed; JDKs that were already there stay.
  for version in ${INSTALLED_HERE[@]+"${INSTALLED_HERE[@]}"}; do
    mise uninstall "java@$version" >/dev/null 2>&1 || true
  done
done

echo
echo "Done: $batch batches in $OUT_DIR"
if [ -s "$OUT_DIR/jdks-failed.txt" ]; then
  echo "Some JDKs failed, see $OUT_DIR/jdks-failed.txt"
fi
