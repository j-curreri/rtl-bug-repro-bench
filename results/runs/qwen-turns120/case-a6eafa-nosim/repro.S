#include "test.h"
#include "hyp.h"

/*
 * Bug: HLVX succeeds even when the VS-stage page table itself lives in
 * guest-physical memory that the G-stage maps execute-only.  The implicit
 * read of a VS-stage PTE is an ordinary load for G-stage permission checks,
 * so the two-stage walk must raise a load guest-page fault (mcause 21).
 *
 * In cva6_ptw.sv, the DTLB permission test applied to a PTE read at the
 * G-intermediate stage (i.e. the physical page that holds a VS-stage PTE)
 * is:
 *   pte.a && ((pte.r && !hlvx) || (pte.x && (mxr || hlvx || ...)))
 * The "pte.x && hlvx" term lets an execute-only G PTE satisfy the check for
 * the implicit VS-PTE load.  A correct implementation checks that read as a
 * load, i.e. it requires pte.r and therefore faults on an execute-only page.
 *
 * Layout built in M-mode, then mret into HS-mode (V=0, S) and issue hlvx.wu:
 *   VS-stage (Sv39):  vs_root, single 1 GiB identity RWX leaf (index 2).
 *   G-stage  (Sv39x4): g_root[2] -> g_l1[0] -> g_l0, 4 KiB identity RWX
 *     leaves for the whole first 2 MiB, EXCEPT g_l0[k_vs] (the 4 KiB page
 *     that holds vs_root) which is execute-only.
 *
 * hlvx.wu of a data word makes the walker G-translate the VA of the VS PTE;
 * the G PTE for that page is execute-only.
 *   correct core: load GPF (21)  -> trap handler sets trap_flag, mret -> PASS
 *   buggy  core:  hlvx completes (no fault) -> trap_flag stays 0        -> FAIL
 */

#define PTE_RWXAD 0xDF   /* G-stage RWX 4 KiB leaf: V|R|W|X|U|A|D */
#define PTE_XONLY 0x59   /* G-stage execute-only 4 KiB leaf: V|X|U|A */

  .section .data
HYP_TABLES                     /* g_root (16 KiB) and vs_root (4 KiB) */
  .align 12
g_l1: .space 4096              /* G-stage level-1 table */
  .align 12
g_l0: .space 4096              /* G-stage level-0 table (4 KiB leaves) */
  .align 3
trap_flag: .dword 0            /* set by trap_handler on the expected GPF */
target:    .dword 0xdeadbeef   /* hlvx.wu operand; value is irrelevant */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* --- VS-stage (Sv39) root: one 1 GiB identity RWX leaf at index 2 --- */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* --- G-stage level-1 pointer: g_root[2] -> g_l1 --- */
  la   s0, g_l1
  srli s0, s0, 12
  slli s0, s0, 10
  ori  s0, s0, PTE_V
  la   s1, g_root
  li   s2, 16                 /* index 2 -> offset 16 */
  add  s1, s1, s2
  sd   s0, 0(s1)

  /* --- G-stage level-0 pointer: g_l1[0] -> g_l0 --- */
  la   s0, g_l0
  srli s0, s0, 12
  slli s0, s0, 10
  ori  s0, s0, PTE_V
  la   s1, g_l1
  sd   s0, 0(s1)

  /* --- g_l0[0..511]: RWX 4 KiB identity leaves for [0x80000000, 0x80200000) --- */
  la   s1, g_l0
  li   s0, 0x80000          /* PPN of 0x80000000; +1 per 4 KiB page */
  li   s2, 512
.Lfill:
  slli s3, s0, 10
  ori  s3, s3, PTE_RWXAD
  sd   s3, 0(s1)
  addi s1, s1, 8
  addi s0, s0, 1
  addi s2, s2, -1
  bnez s2, .Lfill

  /* --- g_l0[k_vs] = execute-only leaf mapping the page that holds vs_root --- */
  la   s0, vs_root           /* GPA (== physical here) of the VS table */
  srli s3, s0, 12
  andi s3, s3, 0x1FF         /* index of this page within the 2 MiB block */
  slli s3, s3, 3
  la   s1, g_l0
  add  s1, s1, s3
  srli s2, s0, 12
  slli s2, s2, 10
  ori  s2, s2, PTE_XONLY
  sd   s2, 0(s1)

  /* --- CSRs --- */
  /* Guest access at supervisor privilege (VS PTEs have U=0). */
  li   t0, HSTATUS_SPVP
  csrs hstatus, t0

  la   s0, vs_root
  VSATP_ON(s0)               /* vsatp = P(vs_root), mode Sv39 */
  HGATP_ON                   /* hgatp = P(g_root),  mode Sv39x4 */

  li   t0, MSTATUS_MPV
  csrc mstatus, t0           /* enter HS-mode (V=0), not VS-mode */

  ENTER_MODE(1, vs_main)     /* mret into S-mode, V=0 -> HS-mode */
  FAIL(2)

vs_main:
  /* HS-mode, two-stage translation active; hlvx.wu forces the two-stage walk. */
  la   t2, target
  hlvx.wu a5, (t2)
  /* Reaching here means hlvx did NOT fault (trap_flag still 0) -> bug present. */
  la   t2, trap_flag
  ld   t2, 0(t2)
  beqz t2, .Lbug
  PASS
.Lbug:
  FAIL(3)

/* Recognise the expected load guest-page fault, skip the hlvx, resume in HS. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 21               /* LOAD_GUEST_PAGE_FAULT */
  bne  t0, t1, .Ltrap_bad
  la   t2, trap_flag
  li   t3, 1
  sd   t3, 0(t2)
  csrr t0, mepc
  addi t0, t0, 4            /* resume at the instruction after hlvx.wu */
  csrw mepc, t0
  mret
.Ltrap_bad:
  FAIL(127)
