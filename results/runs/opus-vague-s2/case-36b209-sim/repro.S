/* Two-stage translation: a VS-stage non-leaf PTE whose next-level table pointer is a
 * guest-physical address with bits 63:41 set. Fetching that next-level PTE needs a
 * G-stage (Sv39x4) translation of an out-of-range GPA, which is a G-stage fault:
 * a guest load in VS-mode must take a load guest-page fault (cause 21).
 * The buggy core reports a plain load page fault (cause 13). */
#include "hyp.h"

  .text
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  beq t0, t1, 1f
  li t1, 13                 /* load page fault: the bug */
  beq t0, t1, 2f
  FAIL(3)                   /* any other trap */
1:
  csrr t0, mstatus          /* trap came from V=1 */
  li t1, MSTATUS_MPV
  and t0, t0, t1
  beqz t0, 3f
  PASS
2:
  FAIL(2)
3:
  FAIL(4)

test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, user, RWX */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 (code, data, tables) */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0xC0000000 -> non-leaf pointer to GPA 0x200_0000_0000 (bit 41 set) */
  RAW_PTE(vs_root, 3, ((0x20000000000 >> 12) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  sfence.vma
  ENTER_VS(guest)

guest:
  li a1, 0xC0000000
  ld a2, 0(a1)
  /* no trap at all */
  FAIL(1)

  HYP_TABLES
