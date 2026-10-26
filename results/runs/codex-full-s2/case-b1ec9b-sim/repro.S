#include "test.h"

/* MRET to a privilege level below M must clear mstatus.MPRV even when
 * the hypervisor extension is absent.  An S-mode ECALL brings us back
 * to M-mode without modifying MPRV, so the handler can check the result.
 * Keep translation disabled and permit all physical accesses: the only
 * property under test is MRET's required update of MPRV (bit 17).
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  li t0, (1 << 3)
  csrc mstatus, t0
  csrw medeleg, zero
  csrw satp, zero
  sfence.vma
  PMP_ALLOW_ALL

  /* All instructions between setting MPRV and entering S are register
   * operations; MPRV does not change instruction-fetch privilege.
   */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, supervisor_entry)

supervisor_entry:
  ecall
  /* The handler terminates the test instead of returning here. */
1:
  j 1b

  .balign 4
  .globl trap_handler
trap_handler:
  /* Save the observed status before clearing MPRV so even the buggy
   * core can reliably write the final result to tohost.
   */
  csrr t1, mstatus
  li t0, (1 << 17)
  csrc mstatus, t0

  csrr t2, mcause
  li t3, 9                      /* Environment call from S-mode. */
  bne t2, t3, unexpected_trap
  csrr t2, mepc
  la t3, supervisor_entry
  bne t2, t3, unexpected_trap

  and t1, t1, t0
  bnez t1, stale_mprv
  PASS

stale_mprv:
  FAIL(1)
unexpected_trap:
  FAIL(2)
