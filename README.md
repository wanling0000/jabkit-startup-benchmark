# jabkit-startup-benchmark

Startup-time measurements for [JabKit](https://github.com/JabRef/jabref/tree/main/jabkit),
JabRef's CLI. Times `jabkit --help` across the ways you can get JabKit (GraalVM native
image, jpackage distribution, JBang, plain `java -jar`) and across Java 25 JDKs, and
records how big each distribution is.

Part of my GSoC 2026 work on native-image builds of JabRef. The current results come from
a single 2-vCPU cloud VM, so the numbers are directional, not a rigorous benchmark; see
the threats to validity in [`results/README.md`](results/README.md).

## What it measures

Warm-cache startup of `--help` (process start + JabKit's own init) via
[hyperfine](https://github.com/sharkdp/hyperfine): 10 warmup runs, then at least 30
measured runs per variant. `--help` avoids the network and the filesystem, so runs stay
comparable.

Two experiments:

1. **Distribution comparison**: the native image, the jpackage portable package, `jbang
   app install jabkit@jabref` and `java -jar` on the fat jar, i.e. the ways a user can
   actually get and run JabKit. Also measures download and on-disk size. All artifacts
   except JBang's come from one official `main` build on builds.jabref.org.
2. **JDK sweep**: the same fat jar under every Java 25 distribution mise offers, plus the
   native image. This asks "same code, which runtime starts fastest", so it reuses the
   artifacts from experiment 1 (or a local build).

## Layout

```
scripts/
  install-jdks.sh          # install all Java 25 distros via mise
  benchmark-jdks.sh        # sweep: every JDK + native image
  benchmark-jdks-batched.sh # same sweep in batches, for machines with little disk
  bench-jbang-vs-native.sh # distribution comparison: native, jpackage, JBang, java -jar
results/                   # committed results, explained in results/README.md
```

## Prerequisites

Linux x86_64: the scripts download the `linux-amd64` artifacts and read machine info
from `/proc`. Needed tools: `hyperfine`, `jbang`, `mise` (sweep only), `curl`, `unzip`,
`tar`. No local Java is required; JBang downloads JDK 25 and `java -jar` reuses it.

The JDK sweep needs disk space for every JDK it installs (roughly 600 MB each).

Building JabKit yourself is optional. To benchmark a local build instead, run
`./gradlew :jabkit:shadowJar :jabkit:nativeCompile` in a JabRef checkout and point the
sweep at it with `JABREF_DIR`. `nativeCompile` needs Liberica NIK; see
[JabRef's native-image build docs](https://devdocs.jabref.org/code-howtos/jabkit-native-image.html).

## Running

**Distribution comparison** (run this first; the sweep below reuses its downloads):

```bash
./scripts/bench-jbang-vs-native.sh   # -> results/distribution-<date>/
```

Downloads the native image, the jpackage portable package and the fat jar from the
JabRef `main` development build on [builds.jabref.org](https://builds.jabref.org/main/),
installs JBang into an isolated home, and benchmarks all four. It also writes `env.txt`
(build version, machine) and `sizes.md`. Set `BUILD_URL` to test another build; note that
`main` is replaced on every upstream commit, so reruns measure a newer build.

**Sweep** (all Java 25 JDKs + native):

```bash
./scripts/install-jdks.sh          # writes /tmp/jabref-java25-jdks.txt
JAR=/tmp/jabkit-dist-bench/jabkit-6.0-all.jar \
NATIVE=/tmp/jabkit-dist-bench/native/jabkit/jabkit \
RESULT_PREFIX=results/runtime-sweep-$(date +%F)/sweep \
  ./scripts/benchmark-jdks.sh
```

`JAR` and `NATIVE` point at the artifacts the distribution comparison downloaded, so both
experiments measure the same build. Leave them unset to use a local build from
`$JABREF_DIR` instead. Other env vars: `JDK_LIST`, `COMMAND_DIR` (see script header).
Output: `<RESULT_PREFIX>.{md,json}`; create the directory first.

If the disk cannot hold every JDK at once, use `benchmark-jdks-batched.sh` instead: it
takes the same `JAR` and `NATIVE`, installs and benchmarks the JDKs in batches of
`BATCH_SIZE` (default 4) with the native image in every batch, and uninstalls each
batch afterwards. Output: `results/runtime-sweep-batched-<date>/`.

`install-jdks.sh` skips any JDK that fails to install, including when the disk runs out
of space, so check the printed list before running the sweep.

## Results

See [`results/README.md`](results/README.md) for the tables, how to read them, the
measurement environment and the threats to validity.

In short, for JabRef `main` build `b6e8511` (2026-10-12): the native image starts in
about 2.2 s, roughly 2x faster than every JVM path (4.2 to 5.4 s), and is the smallest
download (52 MiB, versus 194 MiB for the jpackage distribution).
