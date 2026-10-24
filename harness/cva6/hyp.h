/* Hypervisor helpers. Page tables are built at run time with 1 GiB leaves only.
 * G-stage (Sv39x4) root `g_root` is 16 KiB; VS-stage (Sv39) root `vs_root` is 4 KiB. */
#ifndef HYP_H
#define HYP_H
#include "test.h"

#define PTE_V 0x01
#define PTE_R 0x02
#define PTE_W 0x04
#define PTE_X 0x08
#define PTE_U 0x10
#define PTE_A 0x40
#define PTE_D 0x80
#define G_RWX  (PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D)
#define VS_RWX (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)

#define MSTATUS_GVA (1 << 38)
#define MSTATUS_MPV (1 << 39)
#define HSTATUS_SPVP (1 << 8)
#define SATP_SV39   (8 << 60)

/* table[idx] = 1 GiB leaf mapping to physical address `pa` with `flags`. */
#define GIGA_LEAF(table, idx, pa, flags) \
  RAW_PTE(table, idx, ((pa) >> 12 << 10) | (flags))

/* table[idx] = raw PTE value. */
#define RAW_PTE(table, idx, value) \
  la t0, table;                    \
  li t1, ((idx) * 8);              \
  add t0, t0, t1;                  \
  li t1, value;                    \
  sd t1, 0(t0)

/* Enable G-stage translation with g_root (VMID 0). */
#define HGATP_ON                \
  la t0, g_root;                \
  srli t0, t0, 12;              \
  li t1, SATP_SV39;             \
  or t0, t0, t1;                \
  csrw hgatp, t0;               \
  hfence.gvma

/* Enable VS-stage translation with root at guest-physical address in register `reg`. */
#define VSATP_ON(reg)           \
  srli reg, reg, 12;            \
  li t1, SATP_SV39;             \
  or reg, reg, t1;              \
  csrw vsatp, reg;              \
  hfence.vvma

/* mret into VS-mode at `target`. */
#define ENTER_VS(target)        \
  li t0, MSTATUS_MPV;           \
  csrs mstatus, t0;             \
  ENTER_MODE(1, target)

#define HYP_TABLES              \
  .data;                        \
  .align 14;                    \
  g_root: .space 16384;         \
  .align 12;                    \
  vs_root: .space 4096
#endif
