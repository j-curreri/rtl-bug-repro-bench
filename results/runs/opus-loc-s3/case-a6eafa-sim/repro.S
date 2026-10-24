/*
 * Reproducer: G-stage permission checks on implicit VS-stage page-table reads
 * (core/cva6_mmu/cva6_ptw.sv, G_INTERMED_STAGE leaf handling).
 *
 * Per the hypervisor spec, a VS-stage page-table read made during two-stage
 * translation is checked at G-stage "as though for an implicit load", and like
 * every G-stage access it is a user-level access:
 *   - the G-stage leaf must have U=1, else guest-page fault (21 load, 20 fetch);
 *   - it needs read permission. HLVX's "execute instead of read" rule applies
 *     only to the final data access, not to the implicit page-table reads.
 *
 * The buggy core breaks all of these (U is ignored; under HLVX, the page-table
 * read needs X instead of R). A spec-compliant core gets all four probes right,
 * so the program passes if the baseline works and any probe behaves correctly.
 * The buggy core gets every probe wrong.
 */
#include "hyp.h"

#define MSTATUS_MXR (1 << 19)
#define G_PT_R_U  (PTE_V | PTE_R | PTE_U | PTE_A | PTE_D)   /* G leaf: R, user */
#define G_PT_R    (PTE_V | PTE_R | PTE_A | PTE_D)           /* G leaf: R, no U */
#define G_PT_X_U  (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)   /* G leaf: X-only, user */
#define G_CODE    (PTE_V | PTE_R | PTE_X | PTE_U | PTE_A | PTE_D)

/* table[idx] = leaf/pointer to the host page at `label` with `flags`. */
#define PTE_TO(table, idx, label, flags) \
  la t0, label; srli t0, t0, 12; slli t0, t0, 10; ori t0, t0, flags; \
  la t1, table; sd t0, ((idx) * 8)(t1)

/* vsatp = Sv39, root at guest-physical address `gpa`; flush all translations. */
#define VSROOT(gpa) \
  li t0, ((gpa) >> 12) | SATP_SV39; csrw vsatp, t0; \
  hfence.gvma; hfence.vvma

  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s9, 0                          /* trap handler: 0 = skip insn, else resume at s9 */
  li t0, HSTATUS_SPVP; csrs hstatus, t0

  /* G-stage (Sv39x4): GPA 0x1_0000_0000 + n*4K via g_l1 -> g_l0 */
  PTE_TO(g_root, 4, g_l1, PTE_V)
  PTE_TO(g_l1, 0, g_l0, PTE_V)
  PTE_TO(g_l0, 0, vcode, G_CODE)    /* GPA 0x100000000: code/data page        */
  PTE_TO(g_l0, 2, vs_pt, G_PT_R_U)  /* GPA 0x100002000: VS root, R + U (good) */
  PTE_TO(g_l0, 3, vs_pt, G_PT_R)    /* GPA 0x100003000: VS root, U=0          */
  PTE_TO(g_l0, 4, vs_pt, G_PT_X_U)  /* GPA 0x100004000: VS root, X-only       */
  /* VS-stage root: VA 0..1G -> GPA 0x100000000 (1 GiB leaf) */
  li t0, ((0x100000000 >> 12) << 10) | VS_RWX
  la t1, vs_pt; sd t0, 0(t1)
  la t0, g_root; srli t0, t0, 12; li t1, SATP_SV39; or t0, t0, t1; csrw hgatp, t0

  li s8, 0                          /* number of probes that behaved correctly */

  /* Baseline: HLV.D through a well-formed two-stage mapping must work. */
  VSROOT(0x100002000)
  li t4, 8; li s11, 0; hlv.d t3, (t4)
  beqz s11, 1f
  FAIL(2)
1:li t0, 0x1234
  beq t3, t0, 1f
  FAIL(3)
1:
  /* Probe 1: VS page table in a G-stage page with U=0 -> load guest-page fault. */
  VSROOT(0x100003000)
  li t4, 8; li s11, 0; hlv.d t3, (t4)
  li t0, 21
  bne s11, t0, 1f
  addi s8, s8, 1
1:
  /* Probe 2: HLVX with the VS page table in an R-only (non-X) G-stage page -> OK. */
  VSROOT(0x100002000)
  li t4, 0; li s11, 0; hlvx.wu t3, (t4)
  bnez s11, 1f
  addi s8, s8, 1
1:
  /* Probe 3: HLVX with the VS page table in an X-only G-stage page -> guest-page fault. */
  VSROOT(0x100004000)
  li t4, 0; li s11, 0; hlvx.wu t3, (t4)
  li t0, 21
  bne s11, t0, 1f
  addi s8, s8, 1
1:
  /* Probe 4: VS-mode fetch with the VS page table in a G-stage page with U=0
   * -> instruction guest-page fault (20), not the ecall (10) at the target. */
  VSROOT(0x100003000)
  la s9, 2f; li s11, 0
  li t0, MSTATUS_MPV; csrs mstatus, t0
  li t0, (3 << 11); csrc mstatus, t0
  li t0, (1 << 11); csrs mstatus, t0
  csrw mepc, zero                   /* VA 0 -> vcode */
  mret
2:li t0, 20
  bne s11, t0, 1f
  addi s8, s8, 1
1:
  beqz s8, 1f
  PASS
1:FAIL(1)

/* Record mcause in s11. If s9 != 0, return to s9 in M-mode (from VS-mode code),
 * otherwise skip the faulting 4-byte instruction. */
  .globl trap_handler
  .align 4
trap_handler:
  csrr s11, mcause
  bnez s9, 1f
  csrr t5, mepc; addi t5, t5, 4; csrw mepc, t5
  mret
1:li t5, MSTATUS_MPV; csrc mstatus, t5
  li t5, (3 << 11); csrs mstatus, t5
  csrw mepc, s9
  li s9, 0
  mret

  .align 12
vcode:
  ecall
  j vcode
  .dword 0x1234                     /* VA 8: baseline data */
  .align 12

  .data
  .align 14
g_root: .space 16384
g_l1:   .space 4096
g_l0:   .space 4096
vs_pt:  .space 4096
