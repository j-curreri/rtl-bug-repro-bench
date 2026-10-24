#include "hyp.h"

  HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # G-stage: GPA [0x8000_0000, 0xC000_0000) -> HPA 0x8000_0000
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  # VS-stage: VA [0x8000_0000, 0xC000_0000) -> GPA 0x8000_0000
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  # test data
  la t0, data_word
  li t1, 0x5a5a5a5a5a5a5a5a
  sd t1, 0(t0)

  # enable G-stage (hgatp)
  HGATP_ON
  # enable VS-stage (vsatp): vs_root GPA == its HPA (identity region)
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_VS(vs_main)

vs_main:
  .align 2
  la a0, data_word
  ld t3, 0(a0)
  li t4, 0x5a5a5a5a5a5a5a5a
  bne t3, t4, vs_fail
  PASS
vs_fail:
  FAIL(1)

  .data
  .align 6
data_word: .dword 0
