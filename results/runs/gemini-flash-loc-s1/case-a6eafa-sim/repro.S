#include "test.h"
#include "hyp.h"

HYP_TABLES

.text
.globl trap_handler
trap_handler:
  FAIL(1)

.globl test_main
test_main:
  PMP_ALLOW_ALL

  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  csrw vsatp, x0
  hfence.vvma

  ENTER_VS(vs_entry)

vs_entry:
  la t1, test_data
  ld t2, 0(t1)
  PASS

.data
.align 3
test_data:
  .dword 0x1234567887654321
