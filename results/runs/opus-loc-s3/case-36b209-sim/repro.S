#include "hyp.h"
/* VS-stage root table lives in a guest-physical page whose G-stage leaf has U=0.
 * G-stage accesses are always user-level, so the implicit VS-stage PTE read must
 * raise a load guest-page fault (cause 21). */
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x80000000 -> PA 0x80000000, U=1 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* GPA 0xC0000000 -> PA 0x80000000, U=0 */
  GIGA_LEAF(g_root, 3, 0x80000000, (G_RWX & ~PTE_U))
  /* VS: VA 0x80000000 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  li t3, 0x40000000
  add t2, t2, t3          /* GPA of vs_root through the U=0 alias */
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la t4, value
  li s1, 0
  hlv.d s1, (t4)
  FAIL(1)

  .globl trap_handler
  .align 4
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  .data
  .align 3
value: .dword 0x1234
HYP_TABLES
