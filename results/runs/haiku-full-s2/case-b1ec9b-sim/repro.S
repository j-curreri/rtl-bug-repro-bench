#include "test.h"

/* MRET into S-mode must clear mstatus.MPRV. The buggy core only does this when the
 * H extension is enabled, so MPRV survives the MRET. Back in M-mode after an ecall
 * trap, a data access with MPRV still set uses MPP=S translation. The S-mode page
 * below has U=1 and SUM=0, so that access raises a load page fault. A correct core
 * accesses memory untranslated and reads the probe value. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* root[2]: 1 GiB leaf for DRAM (VA 0x80000000 -> PA 0x80000000), flags V R W X U A D */
  la t0, root
  li t1, 0x200000DF
  sd t1, 16(t0)

  /* Set MPRV, then MRET to S-mode with MPP=S. MRET should clear MPRV. */
  li t0, (1 << 17)                /* mstatus.MPRV */
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9                       /* ecall from S-mode */
  bne t0, t1, bad

  /* Enable Sv39 with the root table. Only M-mode accesses that honour MPRV are affected. */
  la t0, root
  srli t0, t0, 12
  li t1, (8 << 60)
  or t0, t0, t1
  csrw satp, t0
  sfence.vma

  /* M-mode load. Correct core: MPRV=0, untranslated, reads 0x1234.
   * Buggy core: MPRV=1 with MPP=S, page fault (mcause 13) -> nested trap_handler -> bad. */
  la t0, probe
  ld t1, 0(t0)
  li t2, 0x1234
  bne t1, t2, bad_value

  PASS

bad_value:
  FAIL(2)

bad:
  FAIL(1)

  .section .data
  .align 12
root:
  .space 4096
probe:
  .dword 0x1234
