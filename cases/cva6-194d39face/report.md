When a machine-mode interrupt is taken, mtval does not always read as zero in the trap
handler. The privileged spec says mtval is written with zero for interrupts on this core.
