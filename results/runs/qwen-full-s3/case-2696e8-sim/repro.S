/*
 * Bug reproducer: G-stage load-permission check missing on the DTLB-hit path.
 *
 * The G-stage maps one guest 1 GiB page execute-only (R=0,W=0,X=1).
 *   - An HLVX is allowed to treat execute as read, so it succeeds and, in doing
 *     so, fills the DTLB with that execute-only G-stage PTE.
 *   - A plain HLV to the *same* page is then a DTLB hit.  The hit path must
 *     re-check the G-stage read permission for the current access (a plain load
 *     needs R=1), and raise a LOAD GUEST-PAGE-FAULT.  The buggy core skips that
 *     check (g_load_access_ok is computed but never consulted on the load hit
 *     path), so the plain HLV wrongly succeeds.
 *
 * Correct core: the plain HLV traps with mcause == 21 -> PASS.
 * Buggy core:   the plain HLV does not trap -> we reach FAIL -> no PASS.
 *
 * HVA load instructions are not in this toolchain's gas, so they are emitted as
 * raw .word.  Encoding (from the CVA6 decoder): opcode=SYSTEM(0x73), funct3=4,
 * type in [31:20], base in [19:15], rd in [11:7].  base=t1, rd=t0.
 *   HLVX.WU (type=0x683) = 0x683342f3
 *   HLV.W   (type=0x680) = 0x680342f3
 */
#include "test.h"
#include "hyp.h"

/* execute-only G-stage leaf: V|X|U|A|D  (no R, no W) */
#define G_X_ONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

HYP_TABLES                       /* g_root (16 KiB) and vs_root (4 KiB) in .data */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* 1 GiB leaf at root idx 2 ([0x80000000,0xC0000000)). CVA6 PTE PPN is [63:12],
   * so mapping to physical 0x80000000 needs PTE = 0x80000000 | flags.
   * (The harness GIGA_LEAF computes ((pa)>>12<<10) -> PPN=0x20000, i.e. 0x20000000,
   * which is wrong, so write the PTE directly.) */
  RAW_PTE(g_root, 2,  0x80000000 | G_X_ONLY)  /* G-stage: execute-only */
  RAW_PTE(vs_root, 2, 0x80000000 | VS_RWX)    /* VS-stage: read/write/execute */

  HGATP_ON                        /* enable G-stage translation (g_root) */
  la t0, vs_root
  VSATP_ON(t0)                    /* enable VS-stage translation (vs_root) */

  /* mret into HS-mode: S-mode (MPP=1), V=0 (MPV=0) */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  ENTER_MODE(1, hs_entry)

/* HS-mode (V=0, S).  The plain load must fault on a correct core. */
hs_entry:
  la t1, gdata                    /* t1 = guest virtual address to access */
  .word 0x683342f3                /* HLVX.WU t0, (t1): exec-as-read, succeeds, fills DTLB */
  .word 0x680342f3                /* HLV.W   t0, (t1): plain load -> load guest-page fault */
  /* Reached only if the plain load did NOT fault (the bug). */
  FAIL(2)

/* M-mode trap handler (overrides the weak default in crt.S). */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li   t6, 21                     /* riscv::LOAD_GUEST_PAGE_FAULT */
  bne  t5, t6, unexpected_trap
  PASS
unexpected_trap:
  FAIL(99)                        /* a different trap = bad setup, not the target bug */

  .data
gdata: .dword 0x5a5a5a5a
