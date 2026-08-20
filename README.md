# jabkit-startup-benchmark

Startup-time measurements for [JabKit](https://github.com/JabRef/jabref/tree/main/jabkit),
JabRef's CLI. Times `jabkit --help` under a GraalVM native image, a bunch of Java 25 JDKs,
and the JBang launch path.

Part of my GSoC 2026 work on native-image builds of JabRef. Ran on one laptop, so the
numbers are directional, not a rigorous benchmark.

## What it measures

Cold-ish startup of `--help` (process start + JabKit's own init) via
[hyperfine](https://github.com/sharkdp/hyperfine) with warmup. `--help` avoids the
network, filesystem, and any real library, so runs stay comparable.

Two experiments:

1. **Runtime sweep** the same fat jar under every Java 25 distro mise offers, plus the
   native image. This asks "same code, which runtime starts fastest", so it uses locally
   built artifacts (fat jar + `nativeCompile` binary from one checkout, kept same-source).
2. **Distribution comparison** native-image release package vs. `jbang app install
   jabkit@jabref`, i.e. the two "download and run" paths a user actually hits. This asks
   "how fast do you go from download to running", so it uses the published release binary,
   not a local build.

## Layout

```
scripts/
  install-jdks.sh          # install all Java 25 distros via mise
  benchmark-jdks.sh        # sweep: every JDK + native image
  bench-jbang-vs-native.sh # JBang vs native-image release
results/                   # committed .md / .json / .png tables
```

## Prerequisites

```bash
brew install hyperfine mise jbang   # curl, tar, bash assumed present
```

Plus a built JabKit fat jar and native image from a local JabRef checkout (the sweep
reads them from `$JABREF_DIR`):

```bash
# in your JabRef checkout
./gradlew :jabkit:shadowJar        # -> jabkit/build/libs/jabkit-*-all.jar
./gradlew :jabkit:nativeCompile    # -> jabkit/build/native/nativeCompile/jabkit
```

`nativeCompile` needs a GraalVM JDK (via the native-build-tools plugin); set it up per
[JabRef's native-image build docs](https://devdocs.jabref.org/code-howtos/jabkit-native-image.html). If you only want the distribution
comparison, skip the native build and use a released binary instead.

## Running

**Sweep** (all Java 25 JDKs + native):

```bash
./scripts/install-jdks.sh          # writes /tmp/jabref-java25-jdks.txt
JABREF_DIR=~/jabref ./scripts/benchmark-jdks.sh
```

Env vars: `JABREF_DIR`, `JDK_LIST`, `COMMAND_DIR`, `RESULT_PREFIX` (see script header).
Output: `<RESULT_PREFIX>.{md,json}`.

**Distribution comparison**:

```bash
./scripts/bench-jbang-vs-native.sh   # -> jbang-vs-native.{md,json}
```

The release URL points at a `jabkit-native-preview` asset I uploaded to a personal JabRef
fork. Swap it for your own release asset if it's gone.

## Results

Full tables in [`results/`](results/). Two takeaways from this run:

Native image was ~2.4x faster than JBang on the download-and-run path:

| Path | Mean startup |
|---|---|
| JBang (`jabkit@jabref`) | 11.987 ± 2.166 s |
| Native image (release) | 5.017 ± 1.437 s |

In the JDK sweep the native image sat around 4.3 s both runs. The JVMs clustered together
with wide, overlapping error bars, and their order flipped between runs, so I wouldn't
rank them.

The native image's real win here is distribution (no local Java needed), not raw speed
over a warm JVM.
