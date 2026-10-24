#include "hyp.h"

/* Run `target` in VS-mode (mpp=1) or VU-mode (mpp=0); the trap handler records
 * mcause->s1, mstatus->s2, mtval2->s3, mtval->s4, mtinst->s5 and resumes at 1f. */
#define RUN_V(mpp, target)      \
  la s11, 1f;                   \
  li t0, MSTATUS_MPV;           \
  csrs mstatus, t0;             \
  ENTER_MODE(mpp, target);      \
1:

#define EXPECT(reg, val, n)     \
  li t0, val;                   \
  bne reg, t0, fail_##n

/* mpv must be 1, gva must equal g */
#define EXPECT_STATUS(g, n)     \
  srli t0, s2, 38;              \
  andi t0, t0, 3;               \
  li t1, (2 | (g));             \
  bne t0, t1, fail_##n

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* identity G-stage map of 0x80000000..0xBFFFFFFF; 0x40000000 left unmapped */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  csrw medeleg, zero
  csrw hedeleg, zero

  /* 1: ecall from VS */
  RUN_V(1, vs_ecall)
  EXPECT(s1, 10, 1)
  EXPECT_STATUS(0, 1)
  EXPECT(s3, 0, 1)
  EXPECT(s5, 0, 1)

  /* 2: ebreak from VS: mtval = guest virtual pc, gva = 1 */
  RUN_V(1, vs_ebreak)
  EXPECT(s1, 3, 2)
  EXPECT_STATUS(1, 2)
  EXPECT(s3, 0, 2)
  EXPECT(s5, 0, 2)
  la t0, vs_ebreak
  bne s4, t0, fail_2

  /* 3: illegal instruction from VS: mtval holds instruction bits, not a guest
     virtual address, so mstatus.GVA must be 0 (the buggy core sets it to 1) */
  RUN_V(1, vs_illegal)
  EXPECT(s1, 2, 3)
  EXPECT_STATUS(0, 3)
  EXPECT(s3, 0, 3)
  EXPECT(s5, 0, 3)

  /* 4: load guest-page fault */
  RUN_V(1, vs_load_gpf)
  EXPECT(s1, 21, 4)
  EXPECT_STATUS(1, 4)
  EXPECT(s3, (0x40000008 >> 2), 4)
  EXPECT(s4, 0x40000008, 4)

  /* 5: store guest-page fault */
  RUN_V(1, vs_store_gpf)
  EXPECT(s1, 23, 5)
  EXPECT_STATUS(1, 5)
  EXPECT(s3, (0x40000010 >> 2), 5)
  EXPECT(s4, 0x40000010, 5)

  /* 6: instruction guest-page fault */
  RUN_V(1, vs_fetch_gpf)
  EXPECT(s1, 20, 6)
  EXPECT_STATUS(1, 6)
  EXPECT(s3, (0x40000000 >> 2), 6)
  EXPECT(s4, 0x40000000, 6)
  EXPECT(s5, 0, 6)

  /* 7: misaligned load from VS */
  RUN_V(1, vs_misaligned_ld)
  EXPECT(s1, 4, 7)
  EXPECT_STATUS(1, 7)
  EXPECT(s3, 0, 7)

  /* 8: misaligned store from VS */
  RUN_V(1, vs_misaligned_st)
  EXPECT(s1, 6, 8)
  EXPECT_STATUS(1, 8)
  EXPECT(s3, 0, 8)

  /* 9: virtual instruction (hfence.gvma in VS) */
  RUN_V(1, vs_virtinst)
  EXPECT(s1, 22, 9)
  EXPECT_STATUS(0, 9)
  EXPECT(s3, 0, 9)
  EXPECT(s5, 0, 9)

  /* 10: ecall from VU */
  RUN_V(0, vs_ecall)
  EXPECT(s1, 8, 10)
  EXPECT_STATUS(0, 10)
  EXPECT(s3, 0, 10)
  EXPECT(s5, 0, 10)

  /* 11: ebreak from VU */
  RUN_V(0, vs_ebreak)
  EXPECT(s1, 3, 11)
  EXPECT_STATUS(1, 11)
  EXPECT(s3, 0, 11)

  /* 12: load guest-page fault from VU */
  RUN_V(0, vs_load_gpf)
  EXPECT(s1, 21, 12)
  EXPECT_STATUS(1, 12)
  EXPECT(s3, (0x40000008 >> 2), 12)

  /* 13: misaligned load from VU */
  RUN_V(0, vs_misaligned_ld)
  EXPECT(s1, 4, 13)
  EXPECT_STATUS(1, 13)
  EXPECT(s3, 0, 13)


  PASS

#define F(n) fail_##n: FAIL(n)
F(1)
F(2)
F(3)
F(4)
F(5)
F(6)
F(7)
F(8)
F(9)
F(10)
F(11)
F(12)
F(13)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s1, mcause
  csrr s2, mstatus
  csrr s3, mtval2
  csrr s4, mtval
  csrr s5, mtinst
  li t0, (MSTATUS_MPV | MSTATUS_GVA)
  csrc mstatus, t0
  csrw mtval2, zero
  csrw mtinst, zero
  jr s11

  .align 3
vs_ecall:
  ecall
vs_ebreak:
  .option push
  .option norvc
  ebreak
  .option pop
vs_illegal:
  .word 0
vs_load_gpf:
  li t0, 0x40000008
  ld t1, 0(t0)
vs_store_gpf:
  li t0, 0x40000010
  sd t1, 0(t0)
vs_fetch_gpf:
  li t0, 0x40000000
  jr t0
vs_misaligned_ld:
  la t0, buf
  ld t1, 1(t0)
vs_misaligned_st:
  la t0, buf
  sd t1, 3(t0)
vs_virtinst:
  hfence.gvma

  .data
  .align 3
buf: .dword 0, 0

HYP_TABLES
