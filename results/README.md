# Benchmark results

Startup time and download size of JabKit.

## Summary

Test run: 2026-10-12, Azure Linux VM.

- Native image: `jabkit --help` takes about 2.2 s.
- JVM variants: 4.2 to 5.4 s. Native image is about 2x faster.
- Native image download: 52 MiB (137 MiB unpacked).
- jpackage portable download: 194 MiB (250 MiB unpacked).

JabKit build: official JabRef `main` build
[`6.0-beta.184--2026-10-12--b6e8511`](https://github.com/JabRef/jabref/commit/b6e85119ed856fea345ab524de58cb060e5c865b).

## Distribution comparison

| Variant | Mean startup | Download | Unpacked / installed |
|:---|---:|---:|---:|
| Native image | 2.176 ± 0.154 s | 52 MiB | 137 MiB |
| `java -jar` (JDK 25) | 4.172 ± 0.308 s | 113 MiB | 113 MiB + a JDK |
| jpackage portable | 4.352 ± 0.268 s | 194 MiB | 250 MiB |
| JBang (`jabkit@jabref`) | 5.387 ± 0.301 s | — | 437 MiB |

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
- Native image spends about 1.98 s of its 2.2 s as user CPU time (see `startup.json`).
  So the time goes into JabKit's own initialization before it parses the command
  line. Native image removes the JVM startup cost. JabKit's initialization cost
  remains. I have not yet checked which part of the initialization is slow.

A separate run on 2026-10-11 (build
[`4660d5a`](https://github.com/JabRef/jabref/commit/4660d5a82d74ca3f2ff7d30e44858393836891d3))
gave similar numbers:

| Variant | 2026-10-11 | 2026-10-12 |
|:---|---:|---:|
| Native image | 2.08 s | 2.18 s |
| `java -jar` | 4.05 s | 4.17 s |
| jpackage portable | 4.21 s | 4.35 s |
| JBang | 5.01 s | 5.39 s |

Data:

- [`distribution-2026-10-12/env.txt`](./distribution-2026-10-12/env.txt)
- [`distribution-2026-10-12/sizes.md`](./distribution-2026-10-12/sizes.md)
- [`distribution-2026-10-12/startup.md`](./distribution-2026-10-12/startup.md)
- [`distribution-2026-10-12/startup.json`](./distribution-2026-10-12/startup.json)

## Java 25 runtime sweep

Same JabKit fat JAR, run on different Java 25 distributions. To save disk space, the
JDKs run in batches. Every batch also runs the native image as a reference.

Problem: the Azure B2as v2 is a burstable VM. After a few hours of full load, some JVM
runs jumped from about 4 s to 11–14 s. Most likely the VM ran out of CPU credits. Need to
get Azure's CPU credit metrics to confirm this.

### Usable results

| JDK | Batch | Mean [s] | Min [s] | User CPU [s] | vs. native in same batch |
|:---|---:|---:|---:|---:|---:|
| native image (6 usable batches) | — | 2.176–2.216 | — | ~1.98 | 1.00 |
| corretto-25.0.4.10.1 | 1 | 4.151 ± 0.296 | 3.884 | 7.41 | 1.91 |
| liberica-jre-25.0.4.1+1 | 4 | 4.159 ± 0.289 | 3.951 | 7.41 | 1.90 |
| jetbrains-jre-25.0.4.1-b635.70 | 3 | 4.168 ± 0.294 | 3.931 | 7.40 | 1.89 |
| jetbrains-jre-jcef-25.0.4.1-b635.70 | 3 | 4.169 ± 0.278 | 3.979 | 7.43 | 1.89 |
| liberica-25.0.4.1+1 | 4 | 4.195 ± 0.300 | 3.953 | 7.49 | 1.92 |
| kona-25.0.4.b1 | 4 | 4.243 ± 0.402 | 3.983 | 7.49 | 1.94 |
| liberica-lite-25.0.4.1+1 | 5 | 4.379 ± 0.284 | 4.148 | 7.67 | 1.98 |
| liberica-nik-openjdk25-25.0.4.1+1 | 6 | 4.612 ± 0.281 | 4.364 | 8.26 | 2.12 |

- Native image: 2.18–2.22 s in every usable batch.
- The 8 usable JDKs: 4.15–4.61 s. The differences are too small to rank them.
- Native image is 1.9–2.1x faster than each of them.

### Excluded results

A result is excluded if it breaks any rule below. Raw data stays in `batch-N.json`.

| Rule | Condition | What it means |
|---|---|---|
| 1. Bad reference | Native mean in this batch is more than 20% above the median native mean (2.188 s) | The whole VM was slow during this batch. Exclude the whole batch. |
| 2. Jump | Slowest run is more than 2x the fastest run | Conditions changed during the measurement |
| 3. Too much CPU time | User time is more than 50% above the median of all JDKs (7.88 s) | Likely CPU throttling after the credits ran out |
| 4. Waiting for CPU | Wall time is more than 80% of user time (normal: about 56%) | The process waited a lot for a CPU |

| JDK | Batch | Mean [s] | Rules |
|:---|---:|---:|---|
| dragonwell-25.0.4.0.4.7 | 1 | 7.587 | 4 |
| graalvm-community-25.0.2 | 2 | 7.533 | 1, 4 |
| graalvm-community-innovation-25.0.4.1.1 | 2 | 7.670 | 1, 4 |
| jetbrains-25.0.4.1-b635.70 | 2 | 6.167 | 1, 2, 4 |
| jetbrains-jcef-25.0.4.1-b635.70 | 2 | 4.209 | 1 |
| mandrel-25.0.4.1-Final+java25 | 6 | 4.965 | 2 |
| microsoft-25.0.4.1 | 6 | 12.022 | 3 |
| openjdk-25.0.2 | 6 | 11.865 | 3 |
| oracle-25.0.4 | 7 | 12.708 | 3 |
| oracle-graalvm-25.0.4.1.1 | 7 | 14.237 | 3 |
| oracle-graalvm-innovation-25.0.4.1.1 | 7 | 10.590 | 2, 3 |
| sapmachine-25.0.4.1 | 7 | 11.311 | 3 |

- `jetbrains-jcef` looks fine by itself. It is excluded only because of rule 1.
- I picked the thresholds after looking at this data. They work for this run. They are
  not tested on other runs.

### Status

- 8 JDKs: usable.
- 12 JDKs: measured, but disturbed. Need a rerun.
- 9 JDKs: not run yet (sapmachine-jre, semeru-jre-openj9, semeru-openj9, temurin,
  temurin-jre, zulu, zulu-crac, zulu-jre, zulu-jre-crac).
- `-musl` JDKs: skipped. They are for Alpine Linux and cannot run on Ubuntu (glibc).

All raw results are kept. Do not use them to rank JDKs. For a rerun, use a VM with
fixed CPU performance, a physical machine, or pause between batches so the CPU credits
can recover.

Data:

- [`runtime-sweep-batched-2026-10-12/`](./runtime-sweep-batched-2026-10-12/)
- [`runtime-sweep-2026-10-11/`](./runtime-sweep-2026-10-11/)

## Test environment

| Item | Value |
|---|---|
| Date | 2026-10-12 |
| JabKit build | `6.0-beta.184--2026-10-12--b6e8511` |
| Build source | `builds.jabref.org/main` |
| VM | Azure Standard B2as v2 |
| CPU | AMD EPYC 7763, 2 vCPUs |
| Memory | 8 GiB (7.2 GiB visible to the OS) |
| OS | Linux 7.0.0-1012-azure x86_64 |
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
- The burstable CPU disturbed the long JDK sweep. Use the sweep for the rough range
  only.
- The native reference cannot catch every disturbance. Native image mostly uses one
  core, which stays under the VM's 40% CPU baseline. So when the credits ran out,
  native image was almost unaffected. It only caught the slowdown in batch 2, where the
  whole VM was slow.
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
