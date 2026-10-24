/* Reproduce: illegal-instruction trap from VS-mode reports mstatus.GVA = 1.
 *
 * The RISC-V spec requires GVA to indicate whether mtval holds a guest virtual
 * address. For an illegal-instruction trap mtval is (optionally) the faulting
 * instruction, not a guest virtual address, so GVA must be 0. This core, with
 * the CV-X-IF coprocessor interface enabled (CvxifEn=1), routes any illegal
 * instruction to the CVXIF functional unit; when the (absent) coprocessor
 * rejects it, the CVXIF FU raises the illegal-instruction exception with
 * gva = v_i, i.e. mstatus.GVA = 1 in VS-mode. That is the bug.
 *
 * Plan: enter VS-mode, execute an undefined (custom-0) instruction, let it trap
 * into M-mode, and verify that mstatus.GVA is 0. Correct core -> PASS;
 * buggy core -> GVA == 1 -> FAIL.
 */
#include "hyp.h"

  .text
  .globl test_main

test_main:
  PMP_ALLOW_ALL

  /* Illegal-instruction must trap to M-mode, not be delegated to S/HS.
   * medeleg/hedeleg reset to 0, so make it explicit. */
  li t0, 0
  csrw medeleg, t0
  csrw hedeleg, t0

  /* Build 1 GiB identity G-stage and VS-stage tables for the region that
   * holds the program (DRAM at 0x80000000, index 2 of the 1 GiB grid). */
  GIGA_LEAF(g_root,  2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  fence rw, rw

  /* Enable G-stage translation. */
  HGATP_ON

  /* Enable VS-stage translation. */
  la t0, vs_root
  VSATP_ON(t0)

  /* Enter VS-mode and run the illegal instruction. */
  ENTER_VS(vs_illegal)
  FAIL(200)   /* fall through: mret never happened */

vs_illegal:
  /* Undefined custom-0 instruction (opcode 0x0B). 32-bit (bits[1:0]==11),
   * illegal in the main decoder, offloaded to CVXIF, rejected -> illegal
   * instruction exception -> trap into M-mode. */
  .word 0x0000000B
  FAIL(201)   /* fall through: instruction somehow retired without trapping */

/* M-mode trap handler: verify the illegal-instruction trap from VS-mode does
 * not set mstatus.GVA. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 2                 /* CAUSE_ILLEGAL_INSTR */
  bne  t0, t1, not_expected

  csrr t0, mstatus
  /* mstatus.MPV (bit 39) must be 1: we trapped out of virtualization. */
  srli t1, t0, 39
  andi t1, t1, 1
  beq  t1, zero, not_expected
  /* mstatus.MPP (bits [12:11]) must be S (1): previous mode was VS. */
  srli t1, t0, 11
  andi t1, t1, 3
  li   t2, 1
  bne  t1, t2, not_expected

  /* The check: mstatus.GVA (bit 38) must be 0 for an illegal-instruction
   * trap. Buggy core sets it to 1 (== v_i). */
  srli t0, t0, 38
  andi t0, t0, 1
  beq  t0, zero, pass        /* GVA == 0 -> correct */
  FAIL(1)                    /* GVA == 1 -> bug */

not_expected:
  FAIL(2)                    /* unexpected trap / not the target scenario */

pass:
  PASS

  HYP_TABLES
