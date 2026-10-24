#include "test.h"
/*
 * Bug: instruction access check (cva6_mmu.sv `iaccess_err`) does not honour the
 * SUM (permit Supervisor User Memory access) bit.  The data path `daccess_err`
 * does, but the instruction path always raises an instruction page fault when
 * S-mode fetches from a page whose U bit is set, even when mstatus.SUM=1.
 *
 * Per the RISC-V privileged spec, S-mode is allowed to *execute* from a user
 * (U=1) page when SUM is set.  A correct core therefore lets the S-mode payload
 * below run and we end with PASS.  On the buggy core the very first fetch of the
 * U-page payload raises an instruction page fault -> trap -> FAIL.
 *
 * Layout: everything lives in a single 2 MiB "identity" leaf page
 * (VA 0x80000000 -> PA 0x80000000) marked U=1.  The S-stage page table is a
 * level-1 (2M) leaf, so only two PTEs are needed.
 */

  /* PTE flags: V R W X U A D  (no G) */
  .set PTEV, 0x01
  .set PTER, 0x02
  .set PTEW, 0x04
  .set PTEX, 0x08
  .set PTEU, 0x10
  .set PTEA, 0x40
  .set PTED, 0x80
  .set FLAGS, (PTEV|PTER|PTEW|PTEX|PTEU|PTEA|PTED)

  .section .text.init
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* ---- build the S-stage (Sv39) page table: one 2 MiB U-leaf ---- */
  la   t0, root_tab                 /* t0 = physical root table address */
  la   t1, l1_tab                   /* t1 = physical level-1 table address */

  /* l1_tab[0] = 2 MiB leaf for PA base 0x80000000 */
  li   t2, 0x80000000
  srli t2, t2, 12                   /* t2 = PPN = 0x80000 (low 9 bits == 0) */
  li   t3, FLAGS
  sll  t2, t2, 10
  or   t2, t2, t3                   /* t2 = PTE */
  sd   t2, 0(t1)                    /* l1_tab[0] */

  /* root_tab[0] -> l1_tab (V only) */
  srli t3, t1, 12
  sll  t3, t3, 10
  ori  t3, t3, PTEV
  sd   t3, 0(t0)                    /* root_tab[0] */

  /* ---- enable Sv39 translation ---- */
  srli t0, t0, 12                   /* t0 = root PPN */
  sll  t0, t0, 10                   /* t0 = PPN << 10 (satp PPN field, bits [43:10]) */
  li   t1, 8 << 60                  /* SV39 mode */
  or   t0, t0, t1
  csrw satp, t0
  sfence.vma

  /* ---- set mstatus.SUM = 1 (bit 18) ---- */
  li   t0, 1 << 18
  csrs mstatus, t0

  /* ---- enter S-mode at the payload (which lives in the U-page) ---- */
  ENTER_MODE(1, payload)

  /* payload is reached only on a correct core. */
  .text
  .align 2
payload:
  li   a0, 1
  j    _halt

  /* ---- custom trap handler: report mcause as the failure code ---- */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li   a0, 0
  slli a0, t6, 1
  ori  a0, a0, 1
  j    _halt

  .data
  .align 12
root_tab: .space 4096
  .align 12
l1_tab:   .space 4096
