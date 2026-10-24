With G-stage translation enabled and VS-stage translation off (vsatp = Bare), VS-mode cannot
execute code at some valid guest-physical addresses: instruction fetch raises a page fault.
Sv39x4 guest-physical addresses are 41 bits wide and zero-extended.
