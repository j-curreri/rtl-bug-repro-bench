#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map DRAM through G-stage as execute-only. HLVX may read it, but HLV may
   * not. The U bit is set because the implicit guest access is user-eligible. */
  GIGA_LEAF(g_root, 2, 0x80000000,
            (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON

  /* Enter HS-mode with translation for ordinary HS accesses still bare. */
  ENTER_MODE(1, hs_test)

hs_test:
  la t0, probe_data
  hlvx.wu t1, (t0)       /* Allowed by X; caches the G-stage translation. */
  hlv.wu t2, (t0)        /* Must fault: the cached G-stage PTE has R=0. */
  FAIL(1)                /* Reached only if the bad permission is accepted. */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21              /* Load guest-page fault. */
  bne t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(2)

  .section .data
  .align 3
probe_data:
  .dword 0x123456789abcdef0

  HYP_TABLES
