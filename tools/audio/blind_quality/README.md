# Blind paired speech-quality trials for #687

Prepare matched, consented or appropriately licensed clips for the old v0.1
engine and each candidate, using the same input, gain and documented conditions.
This tool does not create audio, recruit listeners, conduct a test, or grant a
release decision. Keep recordings and responses outside Git and never use real
calls or private conversation audio.

Create an operator key and opaque response sheets in a **new directory outside
any checkout**. Protect that directory with suitable OS permissions; share only
the individual listener sheet, never `operator-private.json`:

```
python -m tools.audio.blind_quality.run --output <private-directory> --listeners 10 --scenario clean --scenario quiet --scenario keyboard --scenario fan
```

For every scenario and candidate, the key pairs that candidate against v0.1.
Within each pair, half of listeners hear v0.1 first and half second; trial IDs
and presentation order are shuffled. The operator must play the two correctly
matched clips in that order without exposing model names, and must not reveal the
key until responses are complete. Each listener enters `A`, `B`, or `tie` in
`preferred`, and `yes`, `no`, or `unsure` in `speech_defect`.

After **all** sheets are completed, run:

```
python -m tools.audio.blind_quality.summarize --plan <private-directory>
```

The result contains counts per candidate and scenario, not transcripts, trial
IDs or listener identities. It rejects missing/duplicate votes, incomplete or
unbalanced condition groups and fewer than ten listeners. Ties are reported
separately; if calculating a conservative preference fraction, include ties in
the total. Results explicitly remain `NOT_ASSESSED`: listen for cut words and
artifacts and apply all of #687's device, latency, stability and speech criteria
before any GO decision. No responses or scores exist merely because forms were
generated.
