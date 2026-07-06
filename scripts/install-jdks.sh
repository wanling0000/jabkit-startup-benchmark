#!/usr/bin/env bash

JDK_LIST=/tmp/jabref-java25-jdks.txt

DISTROS=$(mise ls-remote java \
  | grep -E '(^|-)25[.-]' \
  | grep -v javafx \
  | grep -vE '^25[.-]' \
  | sed -E 's/-25[.-].*//' \
  | sort -u \
  | while read d; do
      mise ls-remote java \
        | grep -E "^${d}-25[.-]" \
        | grep -v javafx \
        | tail -1
    done)

: > "$JDK_LIST"

for v in $DISTROS; do
  mise install "java@$v" >/dev/null 2>&1 && mise exec "java@$v" -- java -version >/dev/null 2>&1 \
    && { echo "$v" >> "$JDK_LIST"; echo "installed $v"; } \
    || echo "skip $v"
done

echo
echo "Available JDKs:"
cat "$JDK_LIST"
