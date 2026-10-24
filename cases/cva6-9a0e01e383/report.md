HLVX succeeds even when the VS-stage page table itself lives in guest-physical memory that
the G-stage maps execute-only. The implicit read of a VS-stage PTE is an ordinary load for
G-stage permission checks, so the walk should raise a load guest-page fault.
