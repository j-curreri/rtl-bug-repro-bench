#include "hyp.h"

/* Each case: set s11 = resume label, enter VS at `code`. The M-mode trap
 * handler records mcause/mtval/mtval2/mtinst/mstatus in s1..s5 and jumps to s11. */
#define RUN_VS(code, resume) \
  la s11, resume;            \
  ENTER_VS(code)

#define EXPECT(reg, val, n) \
  li t0, val;               \
  beq reg, t0, 1f;          \
  FAIL(n);                  \
1:

#define EXPECT_GVA_MPV(gva, n)   \
  li t0, MSTATUS_GVA;           \
  and t0, s5, t0;               \
  li t1, ((gva) * MSTATUS_GVA); \
  beq t0, t1, 1f;               \
  FAIL(n);                      \
1:                              \
  li t0, MSTATUS_MPV;           \
  and t0, s5, t0;               \
  bnez t0, 1f;                  \
  FAIL((n)+1);                  \
1:

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  csrw mideleg, zero
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero

  /* 1: ecall from VS */
  RUN_VS(vs_ecall, r1)
r1:
  EXPECT(s1, 10, 2)
  EXPECT(s3, 0, 3)
  EXPECT_GVA_MPV(0, 4)


  /* 3: illegal instruction */
  RUN_VS(vs_illegal, r3)
r3:
  EXPECT(s1, 2, 20)
  EXPECT(s3, 0, 21)
  EXPECT_GVA_MPV(0, 22)

  /* 4: load guest page fault */
  RUN_VS(vs_lgpf, r4)
r4:
  EXPECT(s1, 21, 30)
  EXPECT(s3, (0x40001238 >> 2), 31)
  EXPECT(s2, 0x40001238, 32)
  EXPECT_GVA_MPV(1, 33)

  /* 5: store guest page fault */
  RUN_VS(vs_sgpf, r5)
r5:
  EXPECT(s1, 23, 40)
  EXPECT(s3, (0x40002240 >> 2), 41)
  EXPECT_GVA_MPV(1, 42)

  /* 6: instruction guest page fault */
  RUN_VS(0x40003000, r6)
r6:
  EXPECT(s1, 20, 50)
  EXPECT(s3, (0x40003000 >> 2), 51)
  EXPECT_GVA_MPV(1, 52)

  /* 7: misaligned load */
  RUN_VS(vs_misal_ld, r7)
r7:
  EXPECT(s1, 4, 60)
  EXPECT(s3, 0, 61)
  EXPECT_GVA_MPV(1, 62)

  /* 8: misaligned store */
  RUN_VS(vs_misal_st, r8)
r8:
  EXPECT(s1, 6, 70)
  EXPECT(s3, 0, 71)
  EXPECT_GVA_MPV(1, 72)

  /* 9: virtual instruction (hfence.gvma in VS) */
  RUN_VS(vs_virt, r9)
r9:
  EXPECT(s1, 22, 80)
  EXPECT(s3, 0, 81)
  EXPECT_GVA_MPV(0, 82)


  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr s1, mcause
  csrr s2, mtval
  csrr s3, mtval2
  csrr s4, mtinst
  csrr s5, mstatus
  /* clear MPV/GVA so subsequent M-mode code is unaffected */
  li t0, MSTATUS_MPV | MSTATUS_GVA
  csrc mstatus, t0
  jr s11

vs_ecall:   ecall
vs_ebreak:  ebreak
vs_illegal: .word 0
vs_lgpf:    li a0, 0x40001238; ld a1, 0(a0)
vs_sgpf:    li a0, 0x40002240; sd a1, 0(a0)
vs_misal_ld: la a0, buf+1; ld a1, 0(a0)
vs_misal_st: la a0, buf+1; sd a1, 0(a0)
vs_virt:    hfence.gvma
vs_ldaf:    li a0, 0x80000000; ld a1, 0(a0)
1: j 1b

  .data
  .align 4
buf: .space 32
HYP_TABLES
