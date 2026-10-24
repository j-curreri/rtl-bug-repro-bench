In VS-mode with two-stage translation, a load whose VS-stage walk reaches a non-leaf PTE
pointing outside the guest-physical address space is reported with the wrong exception
cause. The spec requires a guest-page fault in this case.
