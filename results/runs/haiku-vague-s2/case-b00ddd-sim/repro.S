#include "hyp.h"

HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  # G-stage: GPA 0x80000000 identity-mapped (code and data).
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  # VS-stage: VA 0 -> GPA 0 and VA 0x80000000 -> GPA 0x80000000.
  GIGA_LEAF(vs_root, 0, 0x0, VS_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)

vs_code:
  # Illegal instruction in VS-mode. Its mtval is the instruction encoding,
  # not a guest virtual address, so mstatus.GVA must be 0 in M-mode.
  .word 0xffffffff
  FAIL(1)                         # not reached: the trap goes to M-mode

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 2                        # illegal instruction
  bne t6, t5, 1f
  csrr t6, mstatus
  li t5, MSTATUS_MPV
  and t4, t6, t5
  beqz t4, 2f                     # trap came from virtualized mode
  li t5, MSTATUS_GVA
  and t4, t6, t5
  bnez t4, 3f                     # GVA must not be set for this trap
  # Return to M-mode at m_done.
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, m_done
  csrw mepc, t0
  mret
1: FAIL(10)
2: FAIL(11)
3: FAIL(12)

m_done:
  PASS
