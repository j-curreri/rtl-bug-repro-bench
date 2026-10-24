/* Bug reproducer: a plain load (HLV) in VS-mode succeeds when the VS-stage
 * PTE it implicitly reads lives in guest-physical memory that the G-stage
 * maps execute-only.  The implicit VS-stage PTE read is an ordinary load,
 * so G-stage permission checking must deny it and raise a load guest-page
 * fault.  The buggy core permits it, so the load completes.
 *
 * Two-stage translation layout (Sv39 / Sv39x4):
 *
 *   VS-stage (vsatp root at gpa 0xC0000000):
 *     - region 2 (vsva 0x80000000): root PTE -> vs_l1a; vs_l1a[0] = 2 MiB RWX
 *     - region 3 (vsva 0xC0000000): root PTE -> vs_l1b; vs_l1b[0] = 2 MiB RWX
 *
 *   G-stage (hgatp root = g_root):
 *     - region 2 (gpa 0x80000000): 1 GiB RWX leaf  -> 0x80000000 (program)
 *     - region 3 (gpa 0xC0000000): multi-level walk to 4 KiB leaves:
 *         g_l0[0]: gpa 0xC0000000 -> P_vs_root, RWX   (VS root PTE reads)
 *         g_l0[1]: gpa 0xC0001000 -> P_vs_l1a,  RWX   (instruction PTE read)
 *         g_l0[2]: gpa 0xC0002000 -> P_vs_l1b,  X-only (load target PTE read)
 *
 * The VS-mode instruction fetch (region 2) walks a VS PTE that sits in
 * read-allowed G-stage memory, so it always succeeds.  The load target
 * (region 3) walks a VS PTE (vs_l1b[0]) that sits in EXECUTE-ONLY G-stage
 * memory, so its implicit PTE read must fault on a conformant core.
 */
#include "test.h"
#include "hyp.h"

/* G-stage execute-only leaf: V | U | X | A  (no R, no W, no D). */
.equ G_X, 0x59

  .section .data
  HYP_TABLES                  /* g_root (16 KiB) and vs_root (4 KiB) */
  .align 12
  vs_l1a: .space 4096         /* VS level-1 page for region 2 (read-allowed gpa) */
  .align 12
  vs_l1b: .space 4096         /* VS level-1 page for region 3 (execute-only gpa) */
  .align 12
  g_l1: .space 4096          /* G-stage level-1 page for gpa region 3 */
  .align 12
  g_l0: .space 4096          /* G-stage level-0 page for gpa region 3 */
  .align 8
  data_word: .dword 0x1122334455667788

  .section .text
  .globl test_main
  .align 2
test_main:
  PMP_ALLOW_ALL

  /* G-stage region 2 (gpa 0x80000000): 1 GiB leaf, RWX, identity. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  la   a0, vs_root           /* P_vs_root */
  la   a1, vs_l1a           /* P_vs_l1a */
  la   a2, vs_l1b           /* P_vs_l1b */
  la   a3, g_l1             /* P_g_l1 */
  la   a4, g_l0             /* P_g_l0 */

  /* g_root[3] = pointer to g_l1 */
  srli a5, a3, 2
  ori  a5, a5, 1
  la   a6, g_root
  addi a6, a6, 24           /* g_root + 3*8 */
  sd   a5, 0(a6)

  /* g_l1[0] = pointer to g_l0 */
  srli a5, a4, 2
  ori  a5, a5, 1
  sd   a5, 0(a3)

  /* g_l0[0] = 4 KiB leaf, RWX  -> P_vs_root */
  srli a5, a0, 2
  li   a7, G_RWX
  or   a5, a5, a7
  sd   a5, 0(a4)

  /* g_l0[1] = 4 KiB leaf, RWX  -> P_vs_l1a */
  srli a5, a1, 2
  or   a5, a5, a7
  addi a6, a4, 8
  sd   a5, 0(a6)

  /* g_l0[2] = 4 KiB leaf, G_X  -> P_vs_l1b */
  srli a5, a2, 2
  li   a7, G_X
  or   a5, a5, a7
  addi a6, a6, 8
  sd   a5, 0(a6)

  /* vs_root[2] = pointer to gpa 0xC0001000 (vs_l1a) */
  li   a5, 0x30000401
  la   a6, vs_root
  addi a6, a6, 16
  sd   a5, 0(a6)
  /* vs_root[3] = pointer to gpa 0xC0002000 (vs_l1b) */
  li   a5, 0x30000801
  addi a6, a6, 8
  sd   a5, 0(a6)
  /* vs_l1a[0] = vs_l1b[0] = 2 MiB leaf, RWX -> gpa 0x80000000 */
  li   a5, 0x200000cf
  sd   a5, 0(a1)
  sd   a5, 0(a2)

  /* Enable G-stage (hgatp = g_root) and VS-stage (vsatp = 0xC0000000). */
  HGATP_ON
  li   a0, 0xC0000000
  VSATP_ON(a0)

  /* mret into VS-mode. */
  ENTER_VS(vs_main)

  /* M-mode continuation (unreachable after a correct mret). */
  FAIL(2)

  .align 2
vs_main:
  /* Load target = data_word, addressed through VS region 3 (vsva 0xC0000000+off).
   * Its VS PTE (vs_l1b[0]) sits in execute-only G-stage memory, so on a
   * conformant core the implicit PTE read faults and we never reach here. */
  la   t3, data_word         /* t3 = P_data_word */
  li   t4, 0x80000000
  sub  t3, t3, t4            /* t3 = offset within the 2 MiB region */
  li   t5, 0xC0000000
  add  t3, t5, t3            /* t3 = vsva of the load target */
  ld   t6, 0(t3)            /* the load; faulting on a conformant core */
  /* Reached only on the buggy core: the implicit VS-stage PTE read was
   * (incorrectly) permitted through execute-only G-stage memory. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 20               /* guest page faults: 20 instr, 21 load, 23 store */
  blt  t0, t1, th_fail
  li   t1, 23
  bgt  t0, t1, th_fail
  PASS                      /* expected fault: conformant core */
th_fail:
  FAIL(127)
