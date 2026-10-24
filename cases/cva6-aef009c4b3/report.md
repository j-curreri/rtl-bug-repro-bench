On this core, which implements M-mode and U-mode but not S-mode, mstatus reports an XLEN
setting for S-mode. The privileged spec requires the XLEN control field of an unimplemented
privilege mode to be read-only zero.
