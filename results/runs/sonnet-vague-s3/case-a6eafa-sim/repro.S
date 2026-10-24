#include "harness/test.h"
#include "harness/hyp.h"

.globl test_main
.globl trap_handler
.text
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_U|PTE_A|PTE_D))
  GIGA_LEAF(g_root, 0, 0x00000000, G_RWX)
  HGATP_ON
  ENTER_MODE(1, hs_code)

hs_code:
  la a1, data
  hlv.w a2, (a1)       # populate TLB (legal read)
  hlvx.hu a3, (a1)     # no X permission: must raise load guest page fault
  FAIL(1)

trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)

_halt_dummy:
.data
.align 3
data: .dword 0x1234
HYP_TABLES
