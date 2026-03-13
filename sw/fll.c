// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
// Tim Fischer <fischeti@iis.ee.ethz.ch>

#include <stdint.h>
#include "fll.h"
#include "fll_regs.h"

// INFO(fischeti): This is not really tested, but serves as an example.

#ifndef FLL_REGS
// Overwrite the default FLL_REGS definition with the actual base address of the FLL peripheral
#define FLL_REGS ((volatile fll_t *) 0x0)
#endif

// Set the FLL CFG REG 1 to the desired reset value: 0xC958
void init_fll() {
  FLL_REGS->config1.f.mult = 0xC958; // Set the multiplication factor to 0xC958
}

// Set the Multiplication and Divider values
void set_fll_freq(uint32_t mult, uint32_t div) {
  FLL_REGS->config1.f.mult = mult;
  FLL_REGS->config1.f.div = div;
}
