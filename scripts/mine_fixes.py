"""Mine candidate RTL bug-fix commits from a core's git history.

A candidate is a non-merge commit whose message looks like a functional fix,
that touches 1-2 RTL files, and whose RTL diff is small enough to localize.
Writes one JSON object per candidate to stdout.
"""
import argparse
import json
import re
import subprocess

FIX_RE = re.compile(r"\b(fix(e[sd])?|bug(fix)?|incorrect|wrong|erroneous|hang|deadlock|corrupt)\b", re.I)
SKIP_RE = re.compile(r"\b(lint|typo|comment|style|format|doc(s|umentation)?|ci|readme|verible|warning|waiver|spelling|dv|testbench|tb)\b", re.I)


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, check=True).stdout


def main():
    p = argparse.ArgumentParser()
    p.add_argument("repo")
    p.add_argument("--rtl-prefix", action="append", required=True, help="path prefix(es) counted as RTL")
    p.add_argument("--max-lines", type=int, default=40)
    p.add_argument("--max-files", type=int, default=2)
    args = p.parse_args()

    log = git(args.repo, "log", "--no-merges", "--format=%x00%H%x1f%cs%x1f%s", "--numstat")
    for entry in log.split("\0")[1:]:
        header, _, stat = entry.partition("\n")
        sha, date, subject = header.split("\x1f")
        if not FIX_RE.search(subject) or SKIP_RE.search(subject):
            continue
        files = []
        for line in stat.strip().splitlines():
            added, deleted, path = line.split("\t")
            if added == "-":
                continue
            files.append((path, int(added), int(deleted)))
        rtl = [f for f in files if f[0].startswith(tuple(args.rtl_prefix)) and f[0].endswith((".sv", ".v", ".svh", ".vh"))]
        if not rtl or len(rtl) > args.max_files:
            continue
        changed = sum(a + d for _, a, d in rtl)
        if changed > args.max_lines:
            continue
        print(json.dumps({"sha": sha, "date": date, "subject": subject,
                          "rtl_files": [f[0] for f in rtl], "rtl_lines_changed": changed,
                          "other_files": [f[0] for f in files if f not in rtl]}))


if __name__ == "__main__":
    main()
