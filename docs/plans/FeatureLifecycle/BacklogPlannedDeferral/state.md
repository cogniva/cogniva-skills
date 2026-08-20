# BacklogPlannedDeferral — execution state

Status: integrated
Target branch: feature/backlog-changes
Worktree: C:\WorkingGit\cogniva-skills-backlog-planned-deferral (branch feature/backlog-planned-deferral)
Integration: not started

## Log

2026-08-20 — Task 1 done (af86945): rewrote plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md (full replace, verbatim from plan), updated SKILL.md (route-first gate, because: input, do-now wording) and BACKLOG-FORMAT.md (because: tag, Deferred-because stub line, reason-cleared grooming note); created docs/adr/0032-backlog-item-is-a-planned-deferral.md, 0033-confirmation-gate-is-route-first.md, 0034-vague-and-unimportant-is-dropped.md (next free numbers after 0031). Step 14 greps + check-adrs.ps1 clean.

2026-08-20 — Task 2 done (bff4190): re-pointed callers to route-first gate — execute-feature/SKILL.md (Do-now gate, backlog-gate section rewrite), templates/execute-feature.workflow.js (followups description, because property, prompt line with introduced-defect rule), quick-fix/SKILL.md (do-now gate, route-first Follow-ups rule), easy-work-scan/SKILL.md (Step 6 routing), plan-feature/SKILL.md (Handoff pass route-first), explore-idea/SKILL.md (Park-it because:, do-now wording); created docs/adr/0035-introduced-defects-are-unfinished-work.md (ADR-C2 verbatim). Note: Step 10's grep "because" expects a prompt-line hit, but Step 4's verbatim replacement says "defer with a reason" — verbatim text kept; schema-property hit present, "introduced" grep = 2 hits as specified.

2026-08-20 — Task 3 done (ce94fe8): grooming reason-cleared support — GROOMING-CRITERIA.md (actionable-now body now covers cleared because: reasons; new reason-less flag) and groom-backlog SKILL.md Step 3 flags bullet; ADR 0017 amended-by-0034 note, ADR 0019 marked superseded by 0033 (route-first gate), ADR 0020 re-route + not-plan-sized wording; glossary Backlog/Ride-along entries rewritten as planned-deferral/route-first; both BACKLOG.md headers now "Planned deferrals". ADR numbers resolved: vague-and-unimportant = 0034, route-first = 0033. Step 8 greps all clean.

2026-08-20 — Task 4 done (e63494f): cogniva-dev bumped 0.7.0 → 0.7.1 in plugins/cogniva-dev/.claude-plugin/plugin.json, plugins/cogniva-dev/.codex-plugin/plugin.json, and the cogniva-dev entry of .claude-plugin/marketplace.json (cogniva-skills entry untouched at 0.8.0). `claude plugin validate .` passed; check-plugin-manifests.ps1 reported parity OK for 2 plugins.
