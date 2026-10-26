#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Zicntr requires the read-only time counter CSR (0xC01). */
  csrr t0, time
  PASS
