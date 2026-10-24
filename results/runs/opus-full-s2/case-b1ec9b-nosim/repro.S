#include "test.h"

/* MRET to S-mode must clear mstatus.MPRV. Set MPRV=1, mret to S, ecall back
 * to M, then check that MPRV is clear and that M-mode loads are not checked
 * with S-mode PMP permissions. */

  .text
  .globl test_main
test_main:
  /* entry 0: deny-all (no RWX) for `secret` page, applies to S/U only (not locked).
   * entry 1: TOR covering everything else -> RWX. */
  la t0, secret
  srli t0, t0, 2
  ori t0, t0, 0x1ff          /* NAPOT 4 KiB */
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, (0x0f << 8) | 0x18  /* entry1: TOR RWX, entry0: NAPOT no perms */
  csrw pmpcfg0, t0
  csrw satp, zero
  sfence.vma

  li t0, (1 << 17)           /* MPRV */
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                   /* ecall from S */
  bne t0, t1, bad_trap
  /* guard: a load fault from the check below lands here */
  la t0, fault_handler
  csrw mtvec, t0
  /* continue in M (MPP stays S, as set by the trap) */
  j m_check

bad_trap:
  FAIL(3)

  .align 2
fault_handler:
  FAIL(2)

m_check:
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, mprv_set
  /* M-mode load from the S-inaccessible page must succeed */
  la t0, secret
  ld t1, 0(t0)
  li t2, 0x1234
  bne t1, t2, wrong
  PASS
mprv_set:
  FAIL(1)
wrong:
  FAIL(4)

  .data
  .align 12
secret: .dword 0x1234
  .align 12
