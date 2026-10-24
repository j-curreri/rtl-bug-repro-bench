A PMP entry configured in TOR mode does not protect the expected address range when
software writes a pmpaddr value whose lowest bit is set. This core implements a PMP grain of
8 bytes (G=1). A U-mode access just at the boundary of the region is checked against the
wrong entry.
