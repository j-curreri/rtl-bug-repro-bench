"""Print value changes of selected VCD signals over a time window.

    python3 -I scripts/vcd_pick.py dump.vcd --list REGEX          # list matching signal paths
    python3 -I scripts/vcd_pick.py dump.vcd --sig REGEX ... --t0 N --t1 M
"""
import argparse
import re


def parse_header(f):
    scope, ids = [], {}
    for line in f:
        tok = line.split()
        if not tok:
            continue
        if tok[0] == "$scope":
            scope.append(tok[2])
        elif tok[0] == "$upscope":
            scope.pop()
        elif tok[0] == "$var":
            ids.setdefault(tok[3], []).append(".".join(scope + [tok[4]]))
        elif tok[0] == "$enddefinitions":
            return ids
    return ids


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("--list")
    ap.add_argument("--sig", action="append", default=[])
    ap.add_argument("--t0", type=int, default=0)
    ap.add_argument("--t1", type=int, default=1 << 62)
    a = ap.parse_args()
    with open(a.vcd, errors="replace") as f:
        ids = parse_header(f)
        if a.list:
            r = re.compile(a.list)
            for i, names in ids.items():
                for n in names:
                    if r.search(n):
                        print(n)
            return
        pats = [re.compile(s) for s in a.sig]
        want = {i: names[0] for i, names in ids.items() if any(p.search(n) for p in pats for n in names)}
        t = 0
        for line in f:
            if line.startswith("#"):
                t = int(line[1:])
                if t > a.t1:
                    break
                continue
            if t < a.t0:
                continue
            line = line.strip()
            if not line:
                continue
            if line[0] in "bBrR":
                val, i = line[1:].split()
            else:
                val, i = line[0], line[1:]
            if i in want:
                v = val if len(val) <= 2 else hex(int(val.replace("x", "0").replace("z", "0"), 2))
                print(t, want[i].split("i_ariane.i_cva6.")[-1], v)


if __name__ == "__main__":
    main()
