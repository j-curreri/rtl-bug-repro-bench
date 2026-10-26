#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage maps the DRAM gigapage. The U bit is clear: G-stage
     permissions are governed by R/W/X and do not restrict VS accesses. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D))
  /* VS-stage identity map of DRAM, including this code and the data. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(guest_entry)

  .align 2
guest_entry:
  la t0, guest_data
  ld t1, 0(t0)
  li t2, 0x123456789abcdef0
  bne t1, t2, guest_fail
  PASS
guest_fail:
  FAIL(3)

  .align 3
guest_data:
  .dword 0x123456789abcdef0

HYP_TABLES
