#include "test.h"

/* CVA6 implements PMP granularity G=1 (8 bytes; see pmp_entry.sv, NAPOT size =
 * trailing ones + 3). Per the privileged spec, NAPOT forces pmpaddr[G-2:0] to
 * read as ones -- an empty range for G=1 -- so an 8-byte NAPOT region
 * (pmpaddr bit 0 = 0) must read back exactly as written. Only OFF/TOR force
 * pmpaddr[G-1:0] = bit 0 to read as zero. */
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* entry 1: NAPOT, 8-byte region at 0x400, no permissions (M-mode unaffected) */
  li t0, 0x100
  csrw pmpaddr1, t0
  li t0, (0x18 << 8) | 0x1f
  csrw pmpcfg0, t0
  csrr t1, pmpaddr1
  li t0, 0x100
  bne t1, t0, fail

  /* entry 1 in TOR mode with an odd address: bit 0 reads as zero */
  li t0, 0x101
  csrw pmpaddr1, t0
  li t0, (0x08 << 8) | 0x1f
  csrw pmpcfg0, t0
  csrr t1, pmpaddr1
  li t0, 0x100
  bne t1, t0, fail2

  PASS
fail:
  FAIL(1)
fail2:
  FAIL(2)
