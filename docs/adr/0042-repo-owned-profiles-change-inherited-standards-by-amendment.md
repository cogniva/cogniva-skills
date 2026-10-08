# Repo-owned profiles change inherited standards by amendment; a same-id standard is an error

**Provenance:** Suggested by agent
**Relitigation:** Open to discussion

A profile adds new standards under `standards/`, changes an inherited one with
`amendments/<id>` (layered on the inherited text), or supersedes it outright
with `replacements/<id>`, which every resolver output flags. A same-id file in
`standards/` is an error rather than a silent override, because Stage 1's
silent replacement let a profile drop its parent's rules without anyone seeing it.
