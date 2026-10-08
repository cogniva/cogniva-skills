---
description: Outside systems are reached only through a port the owning unit declares; code specific to one system is isolated and depends only on its owner and that system.
---

# External integrations

- An outside system (a database, an API, a file store, a message bus) is
  reached only through a boundary - a port - that the owning unit declares in
  its own terms. The owner depends on the port, never on the outside system.
- Code specific to one outside system - the adapter that implements the port -
  is isolated from the owner, normally in its own unit when the system warrants
  it. It depends only on its owner and on what it needs to reach the system.
