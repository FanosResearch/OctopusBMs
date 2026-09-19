# OctopusBMs — Octopus benchmark traces

The memory-access traces driven through the
[Octopus](https://github.com/FanosResearch/OctopusSimulator) cache-coherence
simulator. They live in this separate repository (`FanosResearch/OctopusBMs`)
so the simulator repository stays lean; the simulator's `get_benchmarks.sh`
clones this into its `BMs/` directory on first use and inflates the compressed
traces automatically.

## Layout

| Directory | Suite | Stored as | Size |
|---|---|---|---|
| `eembc-traces/<bench>/` | EEMBC automotive (10 benches) | plain `trace_C0..C3.trc.shared` | ~57 MB |
| `splash/<bench>/` | SPLASH-2 applications (13 benches) | **xz archives** `trace_C*.trc.shared.xz` | ~650 MB (≈10 GB inflated) |
| `TestBM/` | tiny smoke-test workload | plain `trace_C0..C3.trc.shared` | KB |

Each benchmark is one directory holding one trace per core, `trace_C<n>.trc.shared`.
A trace line is `<addr-hex> <core> <R|W> <cycle>`.

## The SPLASH-2 traces are compressed

The SPLASH-2 set is ~10 GB uncompressed — far over GitHub's 100 MB per-file
limit — so it is stored as **xz** archives (`xz -6`, ~15× smaller, ~650 MB in
total; every archive is under the limit). The tooling also reassembles archives
split into `*.xz.part-00`, `-01`, … pieces, should a future trace ever need it.
Inflate them in place with:

```bash
./prepare_traces.sh            # every suite (idempotent: existing traces are skipped)
./prepare_traces.sh splash     # just SPLASH-2
./prepare_traces.sh --force    # re-inflate even if present
```

The inflated traces are git-ignored here. Budget ~10 GB of disk. Requires `xz`
(`xz-utils` on Linux; part of MSYS2/MinGW on Windows). You only need to run
this by hand if you invoke the simulator binary on a SPLASH benchmark directly —
the simulator's driver scripts do it for you.

## Provenance

EEMBC and SPLASH-2 traces were collected with a gem5-based tracer for a 4-core
system; see the Octopus repository's `REPRODUCIBILITY.md` for how they are
used to reproduce the published results.
