#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* VSATP is writable from M-mode and retains its supported Sv39 fields. */
  li t0, 0x8123456789abcdef
  csrw vsatp, t0
  csrr t1, vsatp
  bne t0, t1, fail_1

  /* An unsupported MODE is WARL: it must leave VSATP unchanged. */
  li t0, 0x9123456789abcdef
  csrw vsatp, t0
  csrr t1, vsatp
  li t2, 0x8123456789abcdef
  bne t1, t2, fail_2

  /* HGATP has a 14-bit VMID, zeroed reserved bits [59:58], and a 16 KiB
     aligned Sv39x4 root PPN (PPN[1:0] are zero). */
  li t0, 0x8abc12345678900f
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0x82bc12345678900c
  bne t1, t2, fail_3

  /* Unsupported HGATP.MODE writes must not change the implemented value. */
  li t0, 0x9abc123456789000
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0x82bc12345678900c
  bne t1, t2, fail_4
  PASS

fail_1: FAIL(1)
fail_2: FAIL(2)
fail_3: FAIL(3)
fail_4: FAIL(4)

  .globl trap_handler
trap_handler:
  FAIL(127)
