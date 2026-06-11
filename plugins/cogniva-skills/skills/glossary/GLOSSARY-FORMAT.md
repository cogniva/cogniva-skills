# Glossary Format

The glossary lives at `docs/glossary/README.md` (the index — always the entry point). Topic files (`docs/glossary/<context>.md`) appear only when the domain grows enough to need them.

## Structure

```md
# Glossary

One agreed meaning per domain term. Reference these in every discussion;
propose new entries as terms emerge.

## Order

A customer's request to purchase; created when checkout completes.
_Avoid_: purchase, transaction

## Invoice

A request for payment sent to a [Customer](#customer) after delivery.
_Avoid_: bill, payment request

## Customer

A person or organization that places [Orders](#order).
_Avoid_: client, buyer, account
```

## Rules

- **Every term is an `## Heading`.** Headings give each term a stable anchor, so terms are linkable from chat, docs, and generated HTML: `[Order](docs/glossary/README.md#order)`.
- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others on an `_Avoid_:` line.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Cross-link related terms** instead of repeating their definitions: `[Customer](#customer)`.
- **Diagrams only where they earn their place.** Add a Mermaid diagram when a flow, relationship, or state is clearer shown than told — never decoratively.
- **No implementation details.** The glossary is not a spec, scratch pad, or decision log (decisions go to `docs/adr/`).
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Write an example dialogue** when boundaries between related terms are subtle — a short dev/domain-expert exchange that demonstrates how the terms interact.

## Single vs multi-context repos

**Single context (most repos):** everything inline in `docs/glossary/README.md`.

**Multiple contexts:** the index links per-context topic files and doubles as the context map. Contexts usually correspond to Modules:

```md
# Glossary

## Contexts

- [Ordering](./ordering.md) — receives and tracks customer orders
- [Billing](./billing.md) — generates invoices and processes payments
- [Fulfillment](./fulfillment.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

The skill infers which structure applies:

- If the index contains a `## Contexts` section, read it to find the topic files
- Otherwise the index is the single glossary
- If no glossary exists, propose creating `docs/glossary/README.md` when the first term is resolved

When multiple contexts exist, infer which one the current topic relates to. If unclear, ask.

## Migrating legacy CONTEXT.md files

Move each `**Term**:` entry to an `## Term` heading, keep the definition and `_Avoid_` line, and relocate the content to `docs/glossary/README.md` (or a topic file per context, with the old `CONTEXT-MAP.md` relationships moving into the index). Delete the legacy files after migration.
