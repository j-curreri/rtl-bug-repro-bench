# Opus episodes silently served by Opus 4.8 (cyber refusal classifier)

Per-episode data: `cyber_downgrades.csv` (regenerate from transcripts; see the script block in
NOTES.md, 2026-10-22).

## What happened

In some Opus episodes a request tripped an upstream refusal classifier. The transcript records a
system event:

```
"type": "refusal", "direction": "retry", "scope": "session",
"original_model": "claude-opus-5-5", "fallback_model": "claude-opus-4-8",
"api_refusal_category": "cyber",
"api_refusal_explanation": "This request triggered restrictions on violative cyber content ..."
```

Because `scope` is `session`, every turn after the stop is served by **claude-opus-4-8**, not the
requested 5.5. This is the same mechanism a human operator saw interactively on 2026-10-22 while
drafting a security advisory for this project.

The literal string `cyber` appears in exactly these transcripts and nowhere else in the run set.

## Affected episodes (8 downgraded to Opus 4.8, category = cyber)

| Run | Episode | Case | Bug | 4.8 turns / total | valid |
| --- | --- | --- | --- | --- | --- |
| opus1 | case-357e26-nosim | cva6-6fe7b95910 | PMP TOR/NA4 | 27/29 | true |
| opus1 | case-a6eafa-nosim | cva6-9a0e01e383 | G-stage U bit | 17/23 | true |
| opus-full-s2 | case-357e26-sim | cva6-6fe7b95910 | PMP TOR/NA4 | 39/40 | true |
| opus-full-s2 | case-357e26-nosim | cva6-6fe7b95910 | PMP TOR/NA4 | 32/34 | true |
| opus-full-s3 | case-357e26-sim | cva6-6fe7b95910 | PMP TOR/NA4 | 54/56 | true |
| opus-full-s3 | case-357e26-nosim | cva6-6fe7b95910 | PMP TOR/NA4 | 31/32 | true |
| opus-vague-s1 | case-357e26-sim | cva6-6fe7b95910 | PMP TOR/NA4 | 105/115 | false |
| opus-vague-s1 | case-2696e8-sim | cva6-2d2d0c11b7 | HLVX exec-only | 52/53 | true |

6 of the 8 are the PMP case cva6-6fe7b95910 (a test showing U-mode defeating memory protection,
which reads as privilege-escalation content to the classifier). 7 of the 8 scored `valid=true`.

## Also: 3 episodes stopped by the classifier without a downgrade

`opus-full-s3/case-2696e8-sim`, `opus-full-s3/case-a6eafa-sim`, `opus1/case-a6eafa-sim`: a single
response was blocked (synthetic "stopped by a safety classifier" message), but there is no
`fallback_model`/session-refusal event and no recorded category; the model stayed opus-5-5 and the
episode ended early (5 turns, `valid=false`). `opus1-retry` is the manual rerun of one such stopped
episode and is already in `EXCLUDE`.

## Why it matters

- `result.json.model` records the **requested** model, so all 8 are labelled `claude-opus-5-5` in
  `episodes.csv`, and `export_results.py` counts them as Opus 5.5. A slice of the reported Opus 5.5
  full/vague numbers was in fact produced by Opus 4.8.
- It is a harness/classifier artifact, not an Opus 5.5 capability result: the model was swapped
  mid-session, not refused on the task's merits.

## Suggested handling

- Add a `served_model` / `downgraded` column to `export_results.py` derived from the transcript
  refusal events (data already in `cyber_downgrades.csv`), and footnote these 8 in the paper; or
- rerun the 8 with the classifier path avoided and label the serving model honestly.
