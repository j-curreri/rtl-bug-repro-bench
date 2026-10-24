/* Reproducer: G-stage read permission not re-checked on DTLB hit.
 *
 * Setup (all in M-mode, physical fetch; traps land in M-mode):
 *   G-stage  (hgatp, Sv39x4, g_root):
 *     GPA 0x8000_0000 -> HPA 0x8000_0000  RWX    (page tables live here)
 *     GPA 0xC000_0000 -> HPA 0x9000_0000  X-only (guest data)
 *   VS-stage (vsatp, Sv39, vs_root):
 *     GVA 0x0000_0000 -> GPA 0xC000_0000  RWX
 *   hstatus.SPVP = 1 so the virtualized access privilege is S.
 *
 * Sequence:
 *   1. HLVX from GVA 0: first access to this page -> DTLB miss -> PTW,
 *      which correctly permits execute-as-read. The DTLB entry is
 *      populated with the G-stage PTE (X-only, u=1).
 *   2. Plain HLV from GVA 0: DTLB hit. The buggy hit path only checks
 *      !dtlb_gpte.u (which is 0 here) and never re-checks G-stage read
 *      permission, so the load succeeds -> FAIL below. A correct core
 *      raises LOAD_GUEST_PAGE_FAULT (mcause 21) -> PASS.
 *
 * This core decodes HLE/HSE with opcode 0x04 (decoder.sv case `3'b100`),
 * not the standard 0x07. Word loads: funct7 = 7'b011_0100, funct3 = 010.
 *   HLVX-WB: rs2 = 0b11 ;  HLV-W: rs2 = 0b00 ;  rs1 = t1 (holds the GVA).
 */
#include "test.h"
#include "hyp.h"

#define G_PAGE_RWX  (PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D) /* 0xff */
#define G_XONLY     (PTE_V | PTE_X | PTE_U | PTE_A)                          /* 0x51 */
#define VS_PAGE_RWX (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)          /* 0x8f */

/* hlvx.wb t2, 0(t1): funct7=0x34 rs2=0b11 rs1=6 f3=2 rd=7 op=0x04 */
#define ENC_HLVX_W  0x68332384
/* hlv.w   t3, 0(t1): funct7=0x34 rs2=0b00 rs1=6 f3=2 rd=8 op=0x04 */
#define ENC_HLV_W   0x68032404

  .data
  HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* guest data at host-physical 0x9000_0000 (plain M-mode write) */
  li t0, 0x90000000
  li t1, 0x123456789abcdef
  sd t1, 0(t0)

  /* G-stage: identity RWX for the page tables; X-only for the guest data */
  GIGA_LEAF(g_root, 2, 0x80000000, G_PAGE_RWX)
  GIGA_LEAF(g_root, 3, 0x90000000, G_XONLY)
  /* VS-stage: GVA region 0 -> GPA 0xc000_0000, fully accessible */
  GIGA_LEAF(vs_root, 0, 0xc0000000, VS_PAGE_RWX)

  /* virtualized-access privilege = S */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* enable both translation stages */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  li t1, 0                      /* GVA = 0x0000_0000 */

  .word ENC_HLVX_W              /* (1) HLVX: fills the DTLB, succeeds on both */
  .word ENC_HLV_W               /* (2) plain HLV: fault on correct, none on buggy */
  FAIL(1)                       /* reached only if (2) did not fault */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t0, 21                     /* LOAD_GUEST_PAGE_FAULT */
  beq t6, t0, expected
  FAIL(127)
expected:
  PASS
