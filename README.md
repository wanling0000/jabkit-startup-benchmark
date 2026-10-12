# jabkit-startup-benchmark

Measures how fast [JabKit](https://github.com/JabRef/jabref/tree/main/jabkit) (JabRef's
CLI) starts, and how big each JabKit distribution is.

I compare:

- the ways to get JabKit: GraalVM native image, jpackage portable, JBang, `java -jar`
- different Java 25 JDKs running the same JAR

Part of my GSoC 2026 work on native-image builds of JabRef. All results come from one
2-vCPU cloud VM, so treat the numbers as rough. Limitations are listed in
[`results/README.md`](results/README.md#limitations).

## What it measures

- Command: `jabkit --help`. It needs no network and no files, so runs are easy to
  compare. It measures process start plus JabKit's own initialization.
- Tool: [hyperfine](https://github.com/sharkdp/hyperfine), 10 warmup runs, then at
  least 30 measured runs per variant. The cache is warm.

Two experiments:

1. **Distribution comparison**: native image, jpackage portable,
   `jbang app install jabkit@jabref`, and `java -jar` on the fat JAR. Also measures
   download and unpacked size. Everything except JBang comes from one official `main`
   build on builds.jabref.org.
2. **JDK sweep**: the same fat JAR on every Java 25 distribution mise offers, plus the
   native image. Question: same code, which runtime starts fastest? It reuses the files
   from experiment 1 (or a local build).

## Layout

```
scripts/
  bench-jbang-vs-native.sh  # distribution comparison: native, jpackage, JBang, java -jar
  install-jdks.sh           # install all Java 25 JDKs via mise
  benchmark-jdks.sh         # JDK sweep: every JDK + native image
  benchmark-jdks-batched.sh # same sweep in batches, for machines with little disk
results/                    # results, explained in results/README.md
```

## Prerequisites

- Linux x86_64. The scripts download the `linux-amd64` files and read machine info from
  `/proc`.
- Tools: `hyperfine`, `jbang`, `mise` (sweep only), `curl`, `unzip`, `tar`.
- No local Java needed. JBang downloads JDK 25, and `java -jar` uses that JDK too.
- Disk: the full JDK sweep needs about 600 MB per JDK.

Building JabKit yourself is optional. To test a local build, run
`./gradlew :jabkit:shadowJar :jabkit:nativeCompile` in a JabRef checkout and set
`JABREF_DIR` for the sweep. `nativeCompile` needs Liberica NIK, see
[JabRef's native-image build docs](https://devdocs.jabref.org/code-howtos/jabkit-native-image.html).

## Running

**1. Distribution comparison.** Run this first. The sweep uses its downloads.

```bash
./scripts/bench-jbang-vs-native.sh   # -> results/distribution-<date>/
```

What it does:

- downloads native image, jpackage portable and fat JAR from the JabRef `main` build on
  [builds.jabref.org](https://builds.jabref.org/main/)
- installs JBang into its own empty home
- benchmarks all four
- writes `env.txt` (build version, machine) and `sizes.md`

`BUILD_URL` picks another build. The `main` build changes with every upstream commit,
so a rerun tests a newer build.

**2. JDK sweep.**

```bash
./scripts/install-jdks.sh          # writes /tmp/jabref-java25-jdks.txt
JAR=/tmp/jabkit-dist-bench/jabkit-6.0-all.jar \
NATIVE=/tmp/jabkit-dist-bench/native/jabkit/jabkit \
RESULT_PREFIX=results/runtime-sweep-$(date +%F)/sweep \
  ./scripts/benchmark-jdks.sh
```

- `JAR` and `NATIVE` point at the files from step 1, so both experiments test the same
  build. Leave them unset to use a local build from `$JABREF_DIR`.
- Other env vars: `JDK_LIST`, `COMMAND_DIR` (see the script header).
- Output: `<RESULT_PREFIX>.{md,json}`. Create the directory first.
- `install-jdks.sh` skips JDKs that fail to install, also when the disk is full. Check
  the printed list before you start the sweep.

**Not enough disk for all JDKs?** Use `benchmark-jdks-batched.sh`. Same `JAR` and
`NATIVE`. It installs `BATCH_SIZE` JDKs at a time (default 4), runs them together with
the native image, then uninstalls them. Output: `results/runtime-sweep-batched-<date>/`.

## Results

Short version, JabRef `main` build `b6e8511` (2026-10-12):

- Native image starts in about 2.2 s. The JVM variants take 4.2 to 5.4 s. So native
  image is about 2x faster.
- Native image is the smallest download: 52 MiB. jpackage portable: 194 MiB.

Tables, test environment and limitations: [`results/README.md`](results/README.md).
