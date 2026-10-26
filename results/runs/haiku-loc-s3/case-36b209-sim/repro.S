#include "hyp.h"

/* VS-stage execute-only leaf: X set, R clear. */
#define VS_XONLY (PTE_V | PTE_X | PTE_A | PTE_D)

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Identity-map GPA 0x80000000 (1 GiB) in the G-stage, RWX. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  /* Identity-map VA 0x80000000 (1 GiB) in the VS-stage as execute-only. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_XONLY)
  la t2, vs_root
  VSATP_ON(t2)
  /* mstatus.MXR=1 (hypervisor view); vsstatus.MXR stays 0. */
  li t0, (1 << 19)
  csrs mstatus, t0
  ENTER_VS(vs_entry)

vs_entry:
  /* Guest load from an execute-only page: vsstatus.MXR=0 so this must fault. */
  la t0, probe
  ld t1, 0(t0)
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  /* 13 = load page fault (expected) */
  li t1, 13
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)

  .data
  .align 3
probe: .dword 0x1234

HYP_TABLES
