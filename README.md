# SDR-Based Motion Detection (PlutoSDR)

A device-free motion sensing project using an ADALM-PLUTO SDR: a single
device continuously transmits a CW tone and receives it with its own
receiver, and motion in the room is inferred from changes in the received
signal's power and phase.

The approach is based on passive RF sensing: when something moves in the
environment, the multipath propagation between TX and RX changes, and that
change leaves a trace in the received signal's power and phase.

## Status

The project has gone through 5 development phases so far (summarized
below). **Work is ongoing** — the current focus is collecting more data
(multiple motion types, multiple rooms) to make the results statistically
more robust.

## Phases

| Phase | File | Purpose |
|---|---|---|
| 1 | `src/faz1_pluto_baglanti_testi.m` | Verify Pluto is detected by MATLAB, print hardware info |
| 2 | `src/faz2_cw_txrx_test.m` | Full-duplex TX/RX test on the same Pluto, TX→RX leakage/SNR measurement using an offset CW tone |
| 3 | `src/faz3_surekli_veri_baseline.m` | Continuous data streaming + live monitoring in an empty room, records a baseline reference |
| 4 | `src/faz4_hareket_testi.m` | Compares a real motion recording against the baseline, suggests an automatic detection threshold |
| 5 | `src/faz5_kalibrasyon_guc_varyansi.m` | Multi-scenario calibration (near/far, slow/fast motion, etc.) based on power variance |

### Key finding (Phase 4 → Phase 5 transition)

Phase 4 originally used **phase variance** as the primary indicator, but
this metric turned out to be too sensitive to hardware artifacts such as
sample loss / USB latency, so it couldn't reliably distinguish motion from
noise. In Phase 5, **power (amplitude) variance** became the main feature
instead, which proved far more robust against these hardware-induced
timing issues. Phase variance is still computed and logged for comparison.

## Folder structure

```
sdr-motion-detection/
├── src/                     # MATLAB scripts (phases 1-5)
├── data/
│   ├── results/             # Small, processed result files (.mat) — tracked in the repo
│   └── raw/                 # Raw IQ recordings — excluded via .gitignore (too large)
└── docs/
    └── screenshots/         # Output plots from phases 3-5
```

> **Note:** Raw IQ `.mat` files placed under `data/raw/` (e.g. a full-length
> baseline recording, which can be tens of MB) are excluded from the repo
> via `.gitignore`. As new room/scenario data is collected, raw recordings
> can go there and stay local-only; only processed/summary results
> (`data/results/`) are version-controlled.

## Screenshots

- **Phase 3 — Live monitoring:** `docs/screenshots/faz3_canli_izleme.png`
- **Phase 4 — Baseline vs. motion:** `docs/screenshots/faz4_baseline_vs_hareket.png`
- **Phase 5 — Power variance comparison:** `docs/screenshots/faz5_guc_varyansi_karsilastirma.png`

## Requirements

- MATLAB (tested with R2025b)
- Communications Toolbox
- Communications Toolbox Support Package for ADALM-PLUTO Radio
- ADALM-PLUTO SDR hardware

## Run order

```
faz1_pluto_baglanti_testi.m     → verify hardware connection
faz2_cw_txrx_test.m             → full-duplex TX/RX and leakage test
faz3_surekli_veri_baseline.m    → record an empty-room baseline (run while the room is empty)
faz4_hareket_testi.m            → record motion, compare against the baseline
faz5_kalibrasyon_guc_varyansi.m → multi-scenario calibration, threshold suggestion
```

## Roadmap (work in progress)

- [ ] Collect more repeated data for multiple motion types (to improve
      statistical reliability)
- [ ] Collect data in multiple different rooms/environments (test
      generalizability)
- [ ] Combine results into a single comparison plot (room × motion type)
- [ ] Make threshold selection more robust (consider moving from a simple
      percentile approach to a probabilistic/ML-based classifier)

## Background

This project was built incrementally with MATLAB + PlutoSDR; each phase
improved on the findings of the previous one — most notably the Phase
4→5 shift from phase variance to power variance, done to gain robustness
against hardware-induced noise.
