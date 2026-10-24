The CBIE field of menvcfg (and senvcfg/henvcfg) can be left holding the reserved encoding
2'b10 after software writes it. The field is WARL and must never read back a reserved value.
