Writing hgatp with an unsupported MODE value appears to be ignored entirely: none of the other
fields change. The hypervisor spec says such a write is not ignored the way it is for satp;
the fields of hgatp are WARL in the normal way.
