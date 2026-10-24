On a core with the hypervisor extension, executing MRET while mstatus.MPP selects M-mode and
mstatus.MPV is set leaves the hart in an inconsistent virtualization state. The spec says MPV
is ignored when returning to M-mode.
