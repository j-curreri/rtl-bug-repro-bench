#include "harness/test.h"
#include "harness/hyp.h"
/* VS-mode with VS-stage translation on; the VS page tables sit in a G-stage
 * page that is execute-only. With mstatus.MXR=1 the implicit page-table reads
 * are allowed, so instruction fetch must succeed. */
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V|PTE_X|PTE_U|PTE_A))
  HGATP_ON
  li t0, 1<<19
  csrs mstatus, t0
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  li t1, 0x3fffffff
  and t2, t2, t1
  li t1, 0x40000000
  or t2, t2, t1
  VSATP_ON(t2)
  ENTER_VS(vs_code)
.align 4
vs_code:
  ecall
.align 4
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10
  beq t0, t1, ok
  FAIL(1)
ok:
  PASS
.data
HYP_TABLES
