#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Seed HGATP with a supported mode and fields distinct from the probe. */
  li t0, 8
  slli t0, t0, 60             /* MODE = Sv39x4 */
  li t1, 1
  slli t1, t1, 44             /* VMID = 1, PPN = 0 */
  or t0, t0, t1
  csrw hgatp, t0

  /* MODE 15 is unsupported. The WARL PPN and VMID fields must still update. */
  la t0, probe_page
  srli t0, t0, 12
  li t1, 2
  slli t1, t1, 44
  or t0, t0, t1
  li t1, 15
  slli t1, t1, 60
  or t0, t0, t1
  csrw hgatp, t0

  csrr t2, hgatp

  /* The selected, 16 KiB-aligned DRAM page must appear in PPN. */
  la t3, probe_page
  srli t3, t3, 12
  li t4, 0x00000fffffffffff
  and t2, t2, t4
  bne t2, t3, fail_ppn

  /* VMID 2 is supported by this configuration and must also be retained. */
  csrr t2, hgatp
  srli t2, t2, 44
  andi t2, t2, 0x7f
  li t3, 2
  bne t2, t3, fail_vmid

  PASS
fail_ppn:
  FAIL(1)
fail_vmid:
  FAIL(2)

  .globl trap_handler
trap_handler:
  FAIL(3)

  .section .data
  .align 14
probe_page:
  .space 16384
