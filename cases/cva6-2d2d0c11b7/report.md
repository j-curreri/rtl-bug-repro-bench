After an HLVX instruction reads from a guest page that the G-stage maps execute-only, a
plain HLV load from the same page also succeeds. HLV should raise a load guest-page fault,
because only HLVX may treat execute permission as read permission.
