# Benchmark results

This directory holds startup-time and distribution-size measurements for JabKit.

## Summary

In the run on 2026-10-12, on an Azure Linux VM, the native image took about 2.2 s on
average to run `jabkit --help`. The JVM-based ways of running JabKit took about 4.2 to
5.4 s, so the native image starts in roughly half the time.

The native image is also the smallest distribution: about 52 MiB to download and
137 MiB unpacked, against 194 MiB and 250 MiB for the jpackage portable package.

All results come from the official JabRef `main` build
[`6.0-beta.184--2026-10-12--b6e8511`](https://github.com/JabRef/jabref/commit/b6e85119ed856fea345ab524de58cb060e5c865b).

## Distribution comparison

| Variant | Mean startup | Download | Unpacked / installed |
|:---|---:|---:|---:|
| Native image | 2.176 ± 0.154 s | 52 MiB | 137 MiB |
| `java -jar` (JDK 25) | 4.172 ± 0.308 s | 113 MiB | 113 MiB, plus an external JDK |
| jpackage portable | 4.352 ± 0.268 s | 194 MiB | 250 MiB |
| JBang (`jabkit@jabref`) | 5.387 ± 0.301 s | — | 437 MiB |

Each variant was warmed up 10 times and then measured 30 times with
[hyperfine](https://github.com/sharkdp/hyperfine).

The native image, the jpackage portable package and the fat JAR come from the same
JabRef CI build. The fat JAR size does not include the JDK it needs. The JBang size is
the whole JBang home after installing into an empty directory, including the JDK,
dependencies and caches it downloaded.

In this run the native image had both the shortest startup time and the smallest
complete runtime. The gap between `java -jar` and the jpackage portable package is
small; this run is not enough to say which of the two is faster.

Of the native image's 2.2 s, about 1.98 s is user CPU time (see `startup.json`). The time
goes into JabKit's initialization before it parses the command line, not into waiting
for disk or network. The native image removes the JVM's own startup cost, but JabKit's
initialization cost remains. Which part of the initialization is slow has not been
investigated yet.

An independent run on 2026-10-11 against build
[`4660d5a`](https://github.com/JabRef/jabref/commit/4660d5a82d74ca3f2ff7d30e44858393836891d3)
gave similar numbers:

| Variant | 2026-10-11 | 2026-10-12 |
|:---|---:|---:|
| Native image | 2.08 s | 2.18 s |
| `java -jar` | 4.05 s | 4.17 s |
| jpackage portable | 4.21 s | 4.35 s |
| JBang | 5.01 s | 5.39 s |

Detailed data:

- [`distribution-2026-10-12/env.txt`](./distribution-2026-10-12/env.txt)
- [`distribution-2026-10-12/sizes.md`](./distribution-2026-10-12/sizes.md)
- [`distribution-2026-10-12/startup.md`](./distribution-2026-10-12/startup.md)
- [`distribution-2026-10-12/startup.json`](./distribution-2026-10-12/startup.json)

## Java 25 runtime sweep

The runtime sweep runs the same JabKit fat JAR on different Java 25 distributions. To
limit disk usage, the JDKs were tested in batches, and every batch included the native
image as a reference.

During the run it turned out that the Azure B2as v2 is a burstable VM. After sustained
high load, some JVM measurements jumped from about 4 s to 11 to 14 s, most likely
because the VM ran out of CPU credits. Confirming the exact cause would need Azure's
CPU credit metrics.

### Results without visible disturbance

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

In the batches without visible throttling:

- the native image's mean stayed between 2.18 and 2.22 s;
- the 8 undisturbed JDKs were between 4.15 and 4.61 s;
- the small differences between JDKs are not enough for a reliable ranking;
- the native image was about 1.9 to 2.1 times faster in every batch.

### Excluded results

A result is excluded from the table above if it meets any of these rules. The raw data
stays in the `batch-N.json` files.

| Rule | Condition | Meaning |
|---|---|---|
| 1. Reference off | The batch's native mean is more than 20% above the median native mean of all batches (2.188 s) | The environment was unstable during this batch; the whole batch is excluded |
| 2. Jump | Slowest run is more than twice the fastest run | The environment changed during the measurement |
| 3. CPU time off | User time is more than 50% above the median of all JDKs (7.88 s) | Likely CPU throttling after the credits ran out |
| 4. Waiting for CPU | Wall time is more than 80% of user time (normally about 56%) | The process spent much of its time waiting for a CPU |

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

`jetbrains-jcef` looks normal on its own; it is excluded only because the native
reference in its batch was off.

The rule thresholds were chosen after looking at this data, so they separate this
particular run well but are not validated beyond it.

The full sweep did not finish under reliable conditions: 12 measured results were
disturbed to some degree, and 9 more JDKs (sapmachine-jre, semeru-jre-openj9,
semeru-openj9, temurin, temurin-jre, zulu, zulu-crac, zulu-jre, zulu-jre-crac) had not
run when the experiment was stopped. All raw results are kept, but they are not used to
rank JDK distributions. To continue the comparison, use a VM with fixed CPU
performance or a physical machine, or pause between batches so the CPU credits can
recover.

JDKs with `-musl` in their name target Alpine Linux and cannot run on the Ubuntu glibc
system used here, so they are outside the scope of this experiment.

Detailed data:

- [`runtime-sweep-batched-2026-10-12/`](./runtime-sweep-batched-2026-10-12/)
- [`runtime-sweep-2026-10-11/`](./runtime-sweep-2026-10-11/)

## Measurement environment

| Item | Value |
|---|---|
| Date | 2026-10-12 |
| JabKit build | `6.0-beta.184--2026-10-12--b6e8511` |
| Build source | `builds.jabref.org/main` |
| VM | Azure Standard B2as v2 |
| CPU | AMD EPYC 7763, 2 vCPUs |
| Memory | 8 GiB (7.2 GiB available to the OS) |
| OS | Linux 7.0.0-1012-azure x86_64 |
| hyperfine | 1.19.0 |
| JBang | 0.142.0 |
| `java -jar` JDK | OpenJDK 25.0.4.1 |

## How to read these results

Following [Verdecchia et al. (2023)](https://doi.org/10.1016/j.infsof.2023.107329),
this section only lists the limitations that materially affect the conclusions.

- The measured command is `jabkit --help`. It mainly reflects process startup and
  JabKit's initialization, not overall performance when processing libraries, PDFs or
  network requests.
- Every command was warmed up 10 times before measurement, so the results describe
  repeated startup after installation, not the first run or a fully cold cache.
- All tests ran on a single 2-vCPU Azure Linux VM. They do not directly carry over to
  other CPUs, physical machines, macOS, Windows or ARM.
- The B2as v2's burstable CPU clearly affected the longer JDK sweep, so the sweep shows
  only a rough range and cannot be used to rank JDKs.
- The native reference in each batch cannot catch every disturbance. The native image
  mostly uses one core and stays under the VM's 40% CPU baseline, so it was barely
  affected when the CPU credits ran out. It only caught disturbances that slowed down
  the whole VM, as in batch 2.
- JBang resolves the `jabkit@jabref` snapshot on its own, so it may not run exactly the
  same code as the other three variants.
- `java -jar` uses the JDK's default options, while the jpackage portable package uses
  the JVM options JabKit configures. The difference between the two is therefore not
  only "bundled runtime or not".
- `builds.jabref.org/main` is updated continuously. When reproducing, go by the build
  version recorded in `env.txt`.

## Historical results

Files with `2026-07-06` or `runtime-sweep-original` in their name are from the first
version of the experiment and are kept only as a historical record.

They used a preview release from a personal fork and did not fully record the source
commit or the environment. Since the code, the native-image toolchain and the method
have all changed, they should not be compared directly with the current results or used
for current conclusions.

## Reproducing

See [Running](../README.md#running) in the top-level README.
