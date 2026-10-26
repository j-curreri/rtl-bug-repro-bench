#include "test.h"

/* Protected page: PMP denies S/U-mode access, M-mode is unaffected (entry not locked). */
  .section .data
  .align 12
prot_page: .space 4096

  .section .text
  .align 2
  .globl test_main
test_main:
  /* PMP entry 0: 4 KiB NAPOT at prot_page, no permissions.
   * PMP entry 1: NAPOT over all memory, RWX. */
  la t0, prot_page
  srli t0, t0, 2
  ori t0, t0, 0x1ff
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f18
  csrw pmpcfg0, t0

  /* Set MPRV, then MRET to S-mode. A correct core clears MPRV on this MRET. */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall

m_resume:
  /* Still in M-mode, MPRV should now be 0, so this access is untranslated M-mode. */
  la t1, prot_page
  ld t2, 0(t1)
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, 1f
  /* Ecall from S-mode: return to m_resume in M-mode. */
  la t0, m_resume
  csrw mepc, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  mret
1:
  csrr t6, mcause
  FAIL(1)
