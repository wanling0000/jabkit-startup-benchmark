# Benchmark results

Startup time and download size of JabKit.

## Summary

Test run: 2026-10-12, Azure Linux VM.

- Native image: `jabkit --help` takes about 2.1 s.
- JVM variants: 4.0 to 5.3 s. Native image is about 2x faster.
- Native image download: 51 MiB (136 MiB unpacked).
- jpackage portable download: 194 MiB (250 MiB unpacked).
- 29 Java 25 JDKs tested: most take about 4.0 s, the fastest 3.7 s, the slowest 5.0 s.
  Native image is faster than all of them.

JabKit build: official JabRef `main` build
[`6.0-beta.189--2026-10-12--01878ae`](https://github.com/JabRef/jabref/commit/01878ae5cd024b01804d5a4d1b83ad4fc6885537).

## Distribution comparison

| Variant | Mean startup | Download | Unpacked / installed |
|:---|---:|---:|---:|
| Native image | 2.139 ± 0.207 s | 51 MiB | 136 MiB |
| `java -jar` (JDK 25) | 4.017 ± 0.321 s | 113 MiB | 113 MiB + a JDK |
| jpackage portable | 4.298 ± 0.424 s | 194 MiB | 250 MiB |
| JBang (`jabkit@jabref`) | 5.280 ± 0.426 s | — | 437 MiB |

Method: [hyperfine](https://github.com/sharkdp/hyperfine), 10 warmup runs, then 30
measured runs per variant.

Notes:

- Native image, jpackage portable and fat JAR come from the same JabRef CI build.
- Fat JAR size: JAR only. You also need a JDK to run it.
- JBang size: the whole JBang home after a fresh install. Includes the JDK and
  dependencies JBang downloads.

Findings:

- Native image is the fastest and has the smallest complete runtime.
- `java -jar` and jpackage portable are very close. This run cannot tell which one is
  faster.
- Native image spends about 1.94 s of its 2.1 s as user CPU time (see `startup.json`).
  So the time goes into JabKit's own initialization before it parses the command
  line. Native image removes the JVM startup cost. JabKit's initialization cost
  remains. I have not yet checked which part of the initialization is slow.

Three runs on three different builds gave similar numbers:

| Variant | 2026-10-11 (`4660d5a`) | 2026-10-12 (`b6e8511`) | 2026-10-12 (`01878ae`) |
|:---|---:|---:|---:|
| Native image | 2.08 s | 2.18 s | 2.14 s |
| `java -jar` | 4.05 s | 4.17 s | 4.02 s |
| jpackage portable | 4.21 s | 4.35 s | 4.30 s |
| JBang | 5.01 s | 5.39 s | 5.28 s |

Data:

- [`distribution-2026-10-12-01878ae/`](./distribution-2026-10-12-01878ae/)
- [`distribution-2026-10-12/`](./distribution-2026-10-12/) (`b6e8511`)
- [`distribution-2026-10-11/`](./distribution-2026-10-11/) (`4660d5a`)

## Java 25 JDK comparison

Same JabKit fat JAR, run on every Java 25 distribution mise offers. To save disk space,
the JDKs run in batches of 4. Every batch also runs the native image as a reference.
After each batch the script pauses so the VM can recover CPU credits (see "First
attempt" below).

### Results

The native image took 2.09–2.15 s in all 12 batches.

| JDK | Batch | Mean [s] | Min [s] | User CPU [s] | vs. native in same batch |
|:---|---:|---:|---:|---:|---:|
| semeru-jre-openj9-25.0.4.15 | 8 | 3.723 ± 0.269 | 3.499 | 5.15 | 1.77 |
| sapmachine-jre-25.0.4.1 | 8 | 3.846 ± 0.335 | 3.647 | 7.01 | 1.83 |
| sapmachine-25.0.4.1 | 7 | 3.847 ± 0.341 | 3.669 | 7.02 | 1.83 |
| semeru-openj9-25.0.4.15 | 9 | 3.875 ± 0.278 | 3.647 | 5.32 | 1.84 |
| openjdk-25.0.2 | 6 | 4.017 ± 0.288 | 3.792 | 7.15 | 1.91 |
| oracle-25.0.4 | 7 | 4.021 ± 0.269 | 3.832 | 7.14 | 1.91 |
| dragonwell-25.0.4.0.4.7 | 1 | 4.034 ± 0.300 | 3.847 | 7.18 | 1.92 |
| zulu-jre-crac-25.36.205.0 | 11 | 4.038 ± 0.292 | 3.850 | 7.19 | 1.93 |
| zulu-25.36.205.0 | 10 | 4.038 ± 0.405 | 3.787 | 7.19 | 1.92 |
| zulu-jre-25.36.205.0 | 11 | 4.041 ± 0.412 | 3.809 | 7.20 | 1.93 |
| kona-25.0.4.b1 | 4 | 4.048 ± 0.284 | 3.840 | 7.22 | 1.91 |
| temurin-jre-25.0.4+101.0.LTS | 9 | 4.053 ± 0.312 | 3.818 | 7.22 | 1.93 |
| jetbrains-jcef-25.0.4.1-b635.70 | 2 | 4.059 ± 0.360 | 3.834 | 7.22 | 1.89 |
| liberica-jre-25.0.4.1+1 | 4 | 4.059 ± 0.305 | 3.873 | 7.22 | 1.92 |
| zulu-crac-25.36.205.0 | 10 | 4.063 ± 0.286 | 3.807 | 7.23 | 1.93 |
| jetbrains-25.0.4.1-b635.70 | 2 | 4.066 ± 0.333 | 3.812 | 7.23 | 1.89 |
| microsoft-25.0.4.1 | 6 | 4.068 ± 0.292 | 3.838 | 7.24 | 1.94 |
| temurin-25.0.4+101.0.LTS | 9 | 4.068 ± 0.360 | 3.836 | 7.23 | 1.94 |
| jetbrains-jre-jcef-25.0.4.1-b635.70 | 3 | 4.070 ± 0.278 | 3.862 | 7.25 | 1.94 |
| mandrel-25.0.4.1-Final+java25 | 6 | 4.074 ± 0.362 | 3.869 | 7.23 | 1.94 |
| liberica-25.0.4.1+1 | 4 | 4.076 ± 0.359 | 3.874 | 7.25 | 1.93 |
| jetbrains-jre-25.0.4.1-b635.70 | 3 | 4.079 ± 0.348 | 3.849 | 7.21 | 1.95 |
| corretto-25.0.4.10.1 | 1 | 4.087 ± 0.421 | 3.855 | 7.22 | 1.95 |
| liberica-lite-25.0.4.1+1 | 5 | 4.216 ± 0.345 | 3.933 | 7.39 | 2.01 |
| liberica-nik-openjdk25-25.0.4.1+1 | 6 | 4.482 ± 0.328 | 4.325 | 8.08 | 2.14 |
| graalvm-community-25.0.2 | 2 | 4.581 ± 0.365 | 4.295 | 8.18 | 2.13 |
| oracle-graalvm-25.0.4.1.1 | 7 | 4.831 ± 0.382 | 4.592 | 8.83 | 2.30 |
| oracle-graalvm-innovation-25.0.4.1.1 | 7 | 4.849 ± 0.327 | 4.640 | 8.84 | 2.31 |
| graalvm-community-innovation-25.0.4.1.1 | 2 | 5.040 ± 0.355 | 4.793 | 9.21 | 2.34 |

Findings:

- Most JDKs take 4.02–4.09 s. The differences are much smaller than the standard
  deviation (about 0.3 s), so I do not rank them.
- The two Semeru JDKs are the fastest and also use clearly less user CPU time (about
  5.2 s, most others about 7.2 s; see the User CPU column). Semeru uses the OpenJ9 JVM,
  most other JDKs use HotSpot. This may be why it is faster, but it needs more checking.
- SapMachine is also a bit faster than most (3.85 s).
- Native image is faster than every JDK: 1.8x faster than the fastest (OpenJ9), 2.3x
  faster than the slowest.

Data: [`runtime-sweep-batched-2026-10-12-01878ae/`](./runtime-sweep-batched-2026-10-12-01878ae/)

### First attempt: disturbed by CPU throttling

The first batched run (build `b6e8511`) had no pauses. The Azure B2as v2 is a burstable
VM with a 40% CPU baseline. After a few hours of full load, some JVM runs jumped from
about 4 s to 11–14 s. Most likely the VM ran out of CPU credits. I could not get Azure's
CPU credit metrics to confirm this.

Example: in one batch, mandrel took about 4.0 s for the first 27 runs, then suddenly
11–15 s for the last 3.

I used these four rules to find the disturbed results:

| Rule | Condition | What it means |
|---|---|---|
| 1. Bad reference | Native mean in this batch is more than 20% above the median of all batches | The whole VM was slow during this batch. Exclude the whole batch. |
| 2. Jump | Slowest run is more than 2x the fastest run | Conditions changed during the measurement |
| 3. Too much CPU time | User time is more than 50% above the median of all JDKs | Likely CPU throttling after the credits ran out |
| 4. Waiting for CPU | Wall time is more than 80% of user time (normal: about 56%) | The process waited a lot for a CPU |

Result: of 29 JDKs, 8 were usable, 12 were disturbed, and 9 had not run yet.

The 8 usable JDKs and where to find them:

| JDK | Mean [s] | Data |
|:---|---:|---|
| corretto-25.0.4.10.1 | 4.151 | [`batch-1`](./runtime-sweep-batched-2026-10-12/batch-1.md) |
| jetbrains-jre-25.0.4.1-b635.70 | 4.168 | [`batch-3`](./runtime-sweep-batched-2026-10-12/batch-3.md) |
| jetbrains-jre-jcef-25.0.4.1-b635.70 | 4.169 | [`batch-3`](./runtime-sweep-batched-2026-10-12/batch-3.md) |
| liberica-jre-25.0.4.1+1 | 4.159 | [`batch-4`](./runtime-sweep-batched-2026-10-12/batch-4.md) |
| liberica-25.0.4.1+1 | 4.195 | [`batch-4`](./runtime-sweep-batched-2026-10-12/batch-4.md) |
| kona-25.0.4.b1 | 4.243 | [`batch-4`](./runtime-sweep-batched-2026-10-12/batch-4.md) |
| liberica-lite-25.0.4.1+1 | 4.379 | [`batch-5`](./runtime-sweep-batched-2026-10-12/batch-5.md) |
| liberica-nik-openjdk25-25.0.4.1+1 | 4.612 | [`batch-6`](./runtime-sweep-batched-2026-10-12/batch-6.md) |

Each `batch-N.md` has the hyperfine table for that batch. `batch-N.json` next to it has
the raw run times and CPU times.

In the rerun with pauses between batches, **none of the four rules fired**. The JDKs
that were disturbed before are back in the normal range. For example, microsoft went
from 12.0 s back to 4.07 s, and dragonwell from 7.6 s back to 4.03 s.

Data: [`runtime-sweep-batched-2026-10-12/`](./runtime-sweep-batched-2026-10-12/)
(`b6e8511`, kept as measured)

## Test environment

| Item | Value |
|---|---|
| Date | 2026-10-12 (started 21:06 UTC, finished the next day) |
| JabKit build | `6.0-beta.189--2026-10-12--01878ae` |
| Build source | `builds.jabref.org/main` |
| VM | Azure Standard B2as v2 |
| CPU | AMD EPYC 7763, 2 vCPUs |
| Memory | 8 GiB (7.2 GiB visible to the OS) |
| OS | Linux 7.0.0-1017-azure x86_64 |
| hyperfine | 1.19.0 |
| JBang | 0.142.0 |
| `java -jar` JDK | OpenJDK 25.0.4.1 |

## Limitations

Based on [Verdecchia et al. (2023)](https://doi.org/10.1016/j.infsof.2023.107329).
Only the points that matter for the conclusions:

- I only measure `jabkit --help`: process startup plus JabKit initialization. Real
  work (libraries, PDFs, network) is not measured.
- 10 warmup runs before measuring. So these numbers are for repeated starts with a warm
  cache. First run is not measured.
- One 2-vCPU Azure Linux VM only. Other CPUs, physical machines, macOS, Windows and
  ARM may give different numbers.
- Burstable CPU: it showed up in the first attempt. The exact CPU credit values are
  unknown.
- `builds.jabref.org/main` changes with every upstream commit. To reproduce, check the
  build version in `env.txt`.

## Historical results

[`history-2026-07-06/`](./history-2026-07-06/) holds the first version of this
experiment. Kept for the record only.

It used a preview release from a personal fork. The source commit and the environment
were not recorded. The code, the native-image toolchain and the method have changed
since then. Do not compare it with the current results.

## Reproducing

See [Running](../README.md#running) in the top-level README.
