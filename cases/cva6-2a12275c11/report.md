When an illegal instruction is executed in VS-mode on a core with the CV-X-IF coprocessor
interface enabled, the trap into M-mode reports mstatus.GVA = 1. For illegal-instruction
traps, mtval does not hold a guest virtual address, so GVA should be 0.
