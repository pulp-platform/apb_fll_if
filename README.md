# APB FLL Interface

Bridges an [APB](https://github.com/pulp-platform/apb) master to one or more ETH FLLs using 4 phase handshake protocol. Up to `2^k − 1` FLLs are supported for any address width `k`; a pseudo-FLL address is reserved for reading back all lock signals in a single cycle.

## Hardware

### Module: `apb_to_fll`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `APBAddrWidth` | `12` | Width of `paddr`; must satisfy `APBAddrWidth − 4 ≥ ⌈log₂(NumFLLs + 1)⌉` |
| `NumFLLs` | `1` | Number of FLL instances |

### Address map

Each FLL exposes 4 × 32-bit registers.  The MSBs of the APB address select the FLL instance, while the 2 LSBs select the register within that FLL.  A reserved pseudo-FLL address is used to read back all lock bits in a single cycle.

| `paddr[4+N−1:4]` | `paddr[3:2]` | Description |
|-----------------|-------------|-------------|
| FLL index `i` | `0x0` | Status (r) |
| FLL index `i` | `0x1` | Config1 (r/w) |
| FLL index `i` | `0x2` | Config2 (r/w) |
| FLL index `i` | `0x3` | Integrator (r/w) |
| `'1` (all ones) | — | Lock read: `prdata[NumFLLs−1:0]` = lock bits, `pready` immediate |

## Software driver

A minimal RISC-V C driver example is provided in `sw/`.  The register header `sw/include/fll_regs.h` is auto-generated from `rdl/fll.rdl` via [PeakRDL](https://github.com/SystemRDL/PeakRDL).

```c
#define FLL_REGS ((volatile fll_t *) 0x<base_addr>)
#include "fll.h"

init_fll();                  // configure multiplication factor
set_fll_freq(0x500, 0x1);   // set mult and clock divider
```

## Simulation

A self-checking open-source testbench is provided in `test/`.  It uses a `fll_model` mock module that implements 4-phase handshake protocol and stores register state for read-back verification.

### Verilator

```bash
make vlt-run [OSEDA="oseda"]  # omit OSEDA= if verilator is on PATH directly
```

### Questasim

```bash
make run-batch   # batch mode
make run         # interactive with waveform logging
```
