# Structure detectors report facts; anything but a valid report is a failed check

**Provenance:** Suggested by agent

A structure detector is a plugin script that a profile names by id. It
compares two git trees, prints one JSON report and exits 0. The report holds
`contract: 1`, the detector's id, and `facts`; each fact has a kind, units,
the repo-relative paths whose profiles govern it, and one line of evidence. An empty `facts` list is the
only way to say "nothing found". Any other exit code, missing or malformed
output, or an unknown id is a failed check, never "no structural changes".
Detectors never read standards or decide whether a change is allowed.
