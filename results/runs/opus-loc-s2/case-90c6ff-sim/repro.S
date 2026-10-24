/* Reproducer: guest-physical address reported in mtval2 on a G-stage fault that
 * hits in the DTLB, for a VS-stage 1 GiB page whose GPA has bit 30 set.
 *
 * VS-stage: VA 0x40000000 (1 GiB) -> GPA 0xC0000000.
 * G-stage:  GPA 0xC0000000 (1 GiB) -> PA 0x80000000, read-only.
 * From HS-mode, HLV.D fills the TLB, then HSV.D to the same address must raise a
 * store guest-page fault with mtval = VA and mtval2 = GPA >> 2.
 * The buggy TLB clears GPA bit 30 when rebuilding the GPA of an S-stage gigapage
 * on a hit, so mtval2 reports (0x80000000 + off) >> 2 instead.
 */
#include "hyp.h"
#define G_RO (PTE_V | PTE_R | PTE_U | PTE_A | PTE_D)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)     /* identity for VS page-table walks */
  GIGA_LEAF(g_root, 3, 0x80000000, G_RO)      /* GPA 0xC0000000 -> PA 0x80000000, RO */
  GIGA_LEAF(vs_root, 1, 0xC0000000, VS_RWX)   /* VA 0x40000000 -> GPA 0xC0000000 */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  la a1, data
  li t0, 0x40000000
  sub a1, a1, t0          /* a1 = VA  = 0x40000000 + off */
  la s2, data
  add s2, s2, t0
  srli s2, s2, 2          /* s2 = GPA >> 2 = (0xC0000000 + off) >> 2 */
  li s11, -1
  ENTER_MODE(1, s_code)

s_code:
  hlv.d a0, (a1)          /* must succeed; fills the TLB */
  li t0, -1
  bne s11, t0, f2
  li s11, -1
  hsv.d zero, (a1)        /* must raise store guest-page fault (TLB hit path) */
  li t0, 23
  bne s11, t0, f3
  bne s9, a1, f4          /* mtval  == VA */
  bne s10, s2, f5         /* mtval2 == GPA >> 2 */
  li a0, 0
  ecall
f2: li a0, 2; ecall
f3: li a0, 3; ecall
f4: li a0, 4; ecall
f5: li a0, 5; ecall

/* M-mode handler: ecall from S ends the test with code a0; any other trap records
 * mcause/mtval/mtval2 and skips the faulting (4-byte) instruction. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t5, mcause
  li t6, 9
  beq t5, t6, 1f
  li t6, 1
  beq t5, t6, 3f
  li t6, 12
  beq t5, t6, 3f
  li t6, 20
  beq t5, t6, 3f
  mv s11, t5
  csrr s9, mtval
  csrr s10, mtval2
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret
3:
  FAIL(6)
1:
  bnez a0, 2f
  PASS
2:
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

  .data
  .align 3
data: .dword 0
HYP_TABLES
