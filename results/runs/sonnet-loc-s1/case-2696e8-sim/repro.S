#include "test.h"
#include "hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V|PTE_X|PTE_U|PTE_A|PTE_D))
  HGATP_ON
  csrw vsatp, zero
  ENTER_MODE(1, hs_code)
.align 2
hs_code:
  la a1, data
  hlvx.wu a2, (a1)
  hlv.w a3, (a1)
  ecall
trap_handler:
  csrr t0, mcause
  li t1, 21
  beq t0, t1, ok
  li t1, 9
  beq t0, t1, bad1
  FAIL(2)
ok:
  PASS
bad1:
  FAIL(1)
.align 3
data: .dword 0x1234
HYP_TABLES
