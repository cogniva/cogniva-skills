---
name: investigate
description: Design, record, or review technical experiments within a continuing investigation, with proportionate rigor and evidence-based challenge. Invoke manually only; experiment execution needs user approval, and accepted documentation normally receives a scoped local commit.
disable-model-invocation: true
---

# Investigate

Use `investigate [design|record|review] [topic-or-record-path]` as the conceptual
invocation, using the current agent host's invocation syntax. Infer an omitted
activity from the request; ask a concise question only when the intended work
cannot be inferred. An explicit invocation can continue across follow-ups and
sessions without re-invocation for each activity change. It does not authorize
monitoring unrelated work.

## Orient

Read applicable repository instructions, data-access restrictions, and relevant
existing records, code, and documentation before asking for discoverable facts.
Resolve an explicit record first; otherwise inspect the established documentation
location for a matching investigation. Avoid broad repository or customer-data
scans. If several records genuinely match, ask which; never merge them automatically.
Before creating, modifying, or interpreting persisted investigation structure,
read [INVESTIGATION-RECORD.md](INVESTIGATION-RECORD.md).

## Collaborate

Work from the technical question and the decision the evidence will inform.
Distinguish unknowns from facts readily answerable through allowed existing
evidence. Ask only questions whose answers materially change the design or
interpretation, and suggest practical defaults. Use no mandatory questionnaire,
form completion, phase order, or statistical ceremony.

## Design

Identify the uncertainty, a testable hypothesis where useful, baseline or control,
bounded method, meaningful measurements, and material confounders or limitations.
Tailor rigor to stakes and cost. Exploratory probes need neither a formal
hypothesis nor a precomputed sample-size target. Discuss what success, failure,
and inconclusiveness would establish and what each would leave open.

## Record

Preserve meaningful positive, negative, mixed, and inconclusive observations with
source attribution and evidence references. Never infer that a proposed experiment
ran. Separate observations, interpretations, and uncertainties; distinguish
user-reported from agent-observed results. Respectfully narrow unsupported
conclusions. When the user disagrees, retain their attributed view alongside a
clear evidence limitation. An informed choice of imperfect methods can proceed
within applicable boundaries; disagreement alone is never a refusal to record or
continue.

## Review

Read the cumulative record and relevant accessible evidence. Summarize supported
findings within their tested conditions, remaining uncertainty, contradictions,
and worthwhile next experiments. Explain missing or inaccessible evidence instead
of inventing verification. When it could materially change understanding, propose
a small targeted follow-up, its benefit, and whether a human, labels, permissions,
or better data is needed. Suggestions never become a queue of automatic actions.

## Execution boundary

Reading, searching, parsing, and calculating summaries of already available,
permitted evidence is allowed when it serves interpretation. Generating new
experimental observations by running tests, benchmarks, inference, experimental
data processing, paid or network experiments, or changing code or data to perform
an experiment requires approval of a concrete proposal: operation, inputs,
intended writes, material cost or external access, and bounded scope.

Approval can cover a specified batch; do not ask again for work within that scope.
An unapproved follow-up, expanded dataset, external service, or materially changed
method needs new approval. Invocation, draft acceptance, or approval of a different
experiment is insufficient. Tool permissions do not substitute for experiment
approval; experiment approval overrides neither data restrictions nor approval
required for outside-repository writes. If a proposed analysis itself tests a new
hypothesis rather than interpreting supplied evidence, present that scope for
approval first.

## Accept and persist

Present the proposed record or diff with the exact intended documentation paths
and explain that acceptance normally saves this exact draft and makes its scoped
local documentation commit. Acceptance never approves experiment execution; a
request to record results does not pre-accept an unseen interpretation. Honor
existing acceptance of the same concrete draft without asking again.

After acceptance, follow the companion's **Acceptance and scoped persistence**
protocol, honoring explicit no-commit instructions and repository or host
constraints. Keep an unaccepted draft in chat or already authorized scratch; never
edit the authoritative record first. End with the supported finding or next useful
question, the record path if any, and the commit SHA or concrete reason it remains
uncommitted. Never push.

Persistence does not automatically invoke explore-idea, plan-feature, adr, or
backlog. Link their existing records where relevant; architectural adoption and
feature implementation need an explicit user request. Give no eligibility
opinions, invented SR&ED narratives, or claim-production workflow. Preserving
honest technical evidence is sufficient.
