/* Reproducer: HLVX on a G-stage page that is readable but not executable.
 *
 * HLVX performs the load as an execute-permission check in the G-stage, so an
 * R-only (X=0) G-stage leaf must raise a load guest-page fault (cause 21).
 * The first access below walks the page table and does fault correctly.
 * Here we first warm the G-stage TLB with a plain HLV.D load, then issue the
 * HLVX.HU load, which hits the cached entry. The buggy core does not check X on
 * that hit, so the HLVX load completes and the ecall is reached instead. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x80000000 -> PA 0x80000000: code and stack, full RWX. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* GPA 0x00000000 -> PA 0x80000000: data window, readable and writable, no X. */
  GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V | PTE_R | PTE_W | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  /* vsatp stays bare, so HLV/HLVX translate through the G-stage only. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, hs_code)

hs_code:
  li t0, 0x100000          /* GVA -> GPA 0x100000 -> PA 0x80100000 */
  hlv.d t1, 0(t0)          /* warms the G-stage TLB entry; must succeed */
hlvx_insn:
  hlvx.hu t2, 0(t0)        /* must raise load guest-page fault (21) on R-only page */
  ecall                    /* reached only if the HLVX load wrongly succeeded */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  csrr t4, mepc
  la t3, hlvx_insn
  bne t4, t3, 1f
  PASS
1: FAIL(127)

HYP_TABLES
