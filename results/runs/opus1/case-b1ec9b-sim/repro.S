#include "test.h"

/* MRET to S-mode must clear MPRV. We set MPRV=1, MPP=S, mret to S, ecall back
 * to M (trap entry sets MPP=S again). If MPRV is stale, M-mode loads are checked
 * with S privilege against a PMP region denying S access -> access fault. */

  .text
  .globl test_main
test_main:
  /* PMP: entry1 = TOR [buf, buf_end) no perms (unlocked: M unaffected),
   *      entry2 = NAPOT all memory RWX. */
  la t0, buf
  srli t0, t0, 2
  csrw pmpaddr0, t0
  la t0, buf_end
  srli t0, t0, 2
  csrw pmpaddr1, t0
  li t0, -1
  csrw pmpaddr2, t0
  li t0, 0x1f0800
  csrw pmpcfg0, t0
  csrw satp, zero
  sfence.vma

  /* sanity: M-mode access to buf works with MPRV=0 */
  la t1, buf
  ld t2, 0(t1)

  li t0, (1 << 17)          /* MPRV */
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall
  FAIL(2)

back_in_m:
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, mprv_set
  la t1, buf
  ld t2, 0(t1)              /* faults if MPRV still applied with MPP=S */
  li t3, 0x1234
  bne t2, t3, fail3
  PASS
mprv_set:
  FAIL(1)
fail3:
  FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 9                  /* ecall from S */
  bne t6, t5, 1f
  j back_in_m          /* stay in M with MPP=S */
1:
  FAIL(4)

  .data
  .align 6
buf: .dword 0x1234
  .align 6
buf_end:
