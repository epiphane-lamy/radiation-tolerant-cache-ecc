# Radiation-Tolerant Cache with ECC — ASIC Flow (GMicro, UFSM Brazil)

Design and evaluation of a 2-way set-associative cache with a custom error-correcting code (ECC) for radiation-tolerant memories, carried out during a research internship at **GMicro (Grupo de Microeletrônica, Universidade Federal de Santa Maria, Brazil)**. The design is pushed through a full ASIC flow (RTL → GDSII) on two PDKs — a standard 45 nm library and an in-house **RHBD** (Radiation-Hardened-By-Design) 180 nm library — to quantify the PPA-F (Power, Performance, Area, Fault-tolerance) trade-off between the two approaches.

📄 Full internship report: [`docs/ECC_RadHardened_Cache_ASIC_Internship_Report.pdf`](docs/ECC_RadHardened_Cache_ASIC_Internship_Report.pdf)

## Context

Electronic circuits are exposed to ionizing radiation in space that can flip memory bits (SEU), corrupt clusters of adjacent cells (MCU), or trigger destructive latch-up (SEL). This project addresses cache-memory reliability at two complementary levels:

- **Architectural mitigation**: a custom ECC, developed at the host lab, based on a linear transformation over GF(2) rather than classic Hamming/BCH codes.
- **Physical mitigation**: an RHBD standard-cell library (Guard Rings, Enclosed-Layout Transistors) protecting against TID and SEL at the layout level.

## Architecture

- **Cache**: 2-way set-associative, 8 indexes, 32-bit lines (2× 8-bit words + ECC redundancy per line), true LRU replacement, write-through / write-allocate policy.
- **Controller**: 5-state FSM (`IDLE`, `FETCH`, `READ_MEM`, `WRITE_MEM`, `WRITE_CACHE`) handling read/write hit and miss paths, with a registered CPU address to align hit detection with synchronous SRAM read latency.
- **ECC**: data word `d` encoded via a bijective linear map `r = A(d)` (100% redundancy, 8→16 bits). Decoding compares the Hamming weight of two syndromes (`data` vs. `redundancy`) to decide whether to trust the raw or reconstructed word — enabling correction of multi-bit clusters, not just single bits.
- **Dual ASIC flow**: same Makefile/RTL targeting either PDK via a `TECH=std|rhbd` switch; RHBD integration required fixing hardened DFF placement (`dont_touch`) and simplifying the power grid (horizontal-only rails) for the 4-metal-layer 180 nm node.

## Validation

- SystemVerilog testbenches for the controller, the ECC encoder/decoder, and the full integrated system (6 functional scenarios: read/write × hit/miss, LRU behavior).
- A Python Monte-Carlo fault-injection model (10k–100k trials per configuration) cross-validated against RTL simulation replaying the same fault vectors — results match within 1.5 percentage points.

## Key results

**Fault tolerance** (adjacent/MCU-style faults, proposed ECC vs. Hamming SECDED):

| Faults | Proposed ECC (adjacent) | Proposed ECC (random) | Hamming SECDED |
|---|---|---|---|
| 1 bit | 100 % | 100 % | 100 % |
| 2 bits | 80 % | 43 % | 0 % |
| 3 bits | 71 % | 16 % | 0 % |
| 4 bits | 31 % | 4 % | 0 % |

For only +3 redundancy bits over SECDED (8 vs. 5 bits), the ECC recovers a majority of 2-3-bit adjacent upsets — directly relevant as shrinking process nodes make multi-cell upsets more likely.

**PPA-F comparison, standard vs. RHBD library:**

| Metric | Standard (45 nm) | RHBD (180 nm) |
|---|---|---|
| Fmax | 335 MHz | 80 MHz |
| Core area | 8 884 µm² | 527 339 µm² (×59) |
| Total power | 0.89 mW | 46.6 mW (×52) |
| SEU/MCU tolerance | Low (raw SRAM) | High (ECC, same as above) |
| TID / SEL tolerance | Low | High (qualitative, RHBD layout) |

The area/power explosion in RHBD is almost entirely geometric (Guard Rings, ELT) and technology-node driven — equivalent gate count grows only ~3.5%, confirming the two protection layers are complementary rather than redundant: ECC handles transient logic-level errors, RHBD protects the silicon against cumulative and destructive effects.

## Repository structure

```
backend/    ASIC flow backend: synthesis & place-and-route scripts (Cadence Genus/Innovus)
frontend/   RTL source code (cache controller, ECC encoder/decoder) and testbenches
config/     Per-library Makefile configuration (standard-cell 45 nm / RHBD 180 nm)
scripts/    Python: Monte-Carlo ECC fault-tolerance evaluation, PPA-F trade-off plots
docs/       Internship report (English and French PDFs)
Makefile    Top-level flow entry point
```

## Toolchain

SystemVerilog · Cadence Genus (synthesis) · Cadence Innovus (place & route) · Python (Monte-Carlo fault modeling)

## Author

Epiphane Lamy — Bordeaux INP, Enseirb-Matmeca, 2A internship — GMicro / Santa Maria Design House, UFSM, Brazil, 2025–2026 (supervisor: João Baptista dos Santos Martins)
