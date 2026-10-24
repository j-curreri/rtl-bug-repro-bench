After an MRET that returns from M-mode to S-mode, software running in M-mode later observes
memory accesses being translated and permission-checked as if MPRV were still in effect.
The privileged spec requires that returning to a mode less privileged than M clears MPRV.
