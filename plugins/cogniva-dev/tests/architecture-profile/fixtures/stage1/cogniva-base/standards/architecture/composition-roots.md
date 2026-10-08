---
description: Composition roots (hosts, entry points) wire owners together and hold no substantive behaviour of their own.
---

# Composition roots

- A composition root - a host, entry point, or startup project - assembles
  owners and registers implementations. Wiring and configuration only.
- Substantive application, domain, persistence, evaluation, or reusable
  behaviour found in a composition root belongs in its owning unit instead.
