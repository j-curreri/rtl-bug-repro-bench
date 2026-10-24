/* Bug reproducer: HLVX must raise a load guest-page fault when the VS-stage
 * page table itself lives in guest-physical memory that the G-stage maps
 * execute-only.
 *
 * The implicit read of a VS-stage PTE is an ordinary load for G-stage
 * permission checks, so a G-stage PTE that is execute-only (X=1, R=0) covering
 * the VS root table MUST fault with a load guest-page fault.  The buggy core
 * instead treats the X bit as satisfying the read requirement whenever the
 * triggering instruction is an HLVX (see cva6_ptw.sv, the PTW leaf permission
 * check uses `pte.x && (... || hlvx_inst_i || ...)` even for the G-stage PTE
 * read at G_INTERMED_STAGE), so the walk succeeds and the load completes.
 *
 * Correct core:  the G-stage PTE read of the VS PTE faults (cause = LOAD_GUEST_PAGE_FAULT)
 *                -> trap_handler PASSes.
 * Buggy core:    the walk completes, the HLVX succeeds, and we fall through to FAIL.
 *
 * Layout (all guest-physical addresses in 0x80000000-0x8FFFFFFF, gpa[40:30]=2):
 *   GPA 0x80000000-0x801FFFFF  -> 2 MiB RWX  (program + data)      [g_l1[0]]
 *   GPA 0x80200000-0x803FFFFF  -> 2 MiB X-only (holds VS root)    [g_l1[1]]  <-- bug target
 *   GPA 0x80400000-0x805FFFFF  -> 2 MiB RWX  (page tables)        [g_l1[2]]
 */
#include "test.h"

/* --- fixed DRAM addresses --- */
#define G_ROOT_ADDR   0x80400000   /* 16 KiB G-stage (Sv39x4) root table     */
#define G_L1_ADDR     0x80410000   /* 4  KiB G-stage level-1 (2 MiB) table   */
#define VS_ROOT_ADDR  0x80200000   /* 4  KiB VS-stage (Sv39) root table      */

/* PTE bits */
#define PTE_V 0x01
#define PTE_R 0x02
#define PTE_W 0x04
#define PTE_X 0x08
#define PTE_U 0x10
#define PTE_A 0x40
#define PTE_D 0x80

/* PTE value from a page-aligned address and permission flags.
 * (matches the harness GIGA_LEAF: ((pa)>>12<<10)|flags == pa|flags when aligned) */
#define PTE(addr, flags) (((addr) & ~0xFFF) | (flags))

/* CVA6 exception-cause code for a load guest-page fault */
#define LOAD_GUEST_PAGE_FAULT 21

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* ---- build g_root: zero 16 KiB, then g_root[2] = pointer to g_l1 ---- */
  li t0, G_ROOT_ADDR
  li t1, 0
  li t2, 2048
1:  sd t1, 0(t0)
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 1b
  li t0, G_ROOT_ADDR + 16                 /* &g_root[2] */
  li t1, PTE(G_L1_ADDR, PTE_V)            /* 0x80410001: valid pointer */
  sd t1, 0(t0)

  /* ---- build g_l1: zero 4 KiB, then three 2 MiB leaves ---- */
  li t0, G_L1_ADDR
  li t1, 0
  li t2, 512
2:  sd t1, 0(t0)
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 2b
  li t0, G_L1_ADDR
  /* g_l1[0]: GPA 0x80000000-0x801FFFFF -> PA 0x80000000, RWX (program) */
  li t1, PTE(0x80000000, PTE_V|PTE_R|PTE_W|PTE_X|PTE_U|PTE_A|PTE_D)
  sd t1, 0(t0)
  /* g_l1[1]: GPA 0x80200000-0x803FFFFF -> PA 0x80200000, X-only (holds VS root) */
  li t1, PTE(0x80200000, PTE_V|PTE_X|PTE_U|PTE_A|PTE_D)
  sd t1, 8(t0)
  /* g_l1[2]: GPA 0x80400000-0x805FFFFF -> PA 0x80400000, RWX (page tables) */
  li t1, PTE(0x80400000, PTE_V|PTE_R|PTE_W|PTE_X|PTE_U|PTE_A|PTE_D)
  sd t1, 16(t0)

  /* ---- build vs_root: zero 4 KiB, then vs_root[0] = 1 GiB leaf ---- */
  li t0, VS_ROOT_ADDR
  li t1, 0
  li t2, 512
3:  sd t1, 0(t0)
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 3b
  /* vs_root[0]: VA[0,1GiB) -> GPA 0x80000000, R|X|A|D (data page RWX in G) */
  li t1, PTE(0x80000000, PTE_V|PTE_R|PTE_X|PTE_A|PTE_D)
  sd t1, 0(t0)

  /* ---- enable G-stage (hgatp) and VS-stage (vsatp), both Sv39 ---- */
  li t0, G_ROOT_ADDR >> 12                /* G root PPN */
  li t1, 8 << 60                          /* Sv39 mode  */
  or t0, t0, t1
  csrw 0x680, t0                          /* hgatp */
  li t0, VS_ROOT_ADDR >> 12               /* VS root PPN (a guest-physical addr) */
  li t1, 8 << 60
  or t0, t0, t1
  csrw 0x280, t0                          /* vsatp */
  hfence.gvma
  hfence.vvma

  /* ---- two-stage HLVX: the VS PTE (GPA 0x80200000) sits in the X-only G region ---- */
  li t3, 0x1000                           /* guest virtual address in [0,1GiB) */
  hlvx.wu t4, 0(t3)
  /* Reaching here means the G-stage PTE read did NOT fault => buggy core. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  /* DEBUG: encode mcause (bits [15:1]) and bad-GPA PPN (bits [..:16]) into tohost */
  csrr t0, mcause
  csrr t1, mtval2
  srli t1, t1, 12
  slli t0, t0, 1
  ori  t0, t0, 1
  slli t1, t1, 16
  or   t0, t0, t1
  mv   a0, t0
  j _halt
