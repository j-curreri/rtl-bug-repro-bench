/* MRET to S-mode must clear MPRV. Root page table maps the 0x80000000 gigapage
 * execute-only, so S-mode can run but any MPRV-translated data access faults.
 * After returning to M-mode via ecall, a plain load must use physical access. */
#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, pt_root
  srli t0, t0, 12
  li t1, (8 << 60)
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  li t0, (1 << 17)          /* MPRV=1 */
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall

m_check:
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, fail_mprv
  la t0, magic
  ld t1, 0(t0)
  li t2, 0x1234abcd
  bne t1, t2, fail_val
  PASS
fail_mprv:
  FAIL(1)
fail_val:
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 9                  /* ecall from S */
  bne t6, t5, bad_trap
  la t0, m_check
  jr t0
bad_trap:
  FAIL(3)

  .data
  .align 12
pt_root:
  .dword 0, 0
  .dword 0x20000049         /* VA 0x80000000 -> PA 0x80000000, V|X|A */
  .fill 509, 8, 0
magic:
  .dword 0x1234abcd
