---
title: Project Context Format
description: Defines the structure and content of PROJECT-CONTEXT.md
---

# Project Context Reference

This file contains the high-level business context for the project. It is intended to be a "Source of Truth" for why we are building things, not how they are built.

## Sections
The document is organized into the following standard sections:

### 1. Mission
The core purpose and goals of the product. What problem does it solve?

### 2. Stakeholders
Who are the primary users and who are the business owners?

### 3. Business Rules
Rules that govern behavior from a non-technical perspective (e.g., pricing, legal requirements, permissions).

### 4. Constraints
Technical or environmental limitations (e.g., "Must run on mobile", "Cannot share PII"). **MUST** include deadline constraints. If the deadline constraints aren't known, you can say something similar to "**Deadline constraints** - not currently known."

## Formatting Guidelines
- **No Technical Debt:** Do not include bug IDs, implementation details, or technical debt notes here.
- **High Signal Only:** Focus on the "why" and the business logic.
- **Concise Definitions:** Keep descriptions clear and punchy.
- **Internal Links:** Use links to other documents (e.g., `[Glossary](docs/glossary/README.md#term)`) when appropriate.

## Update Protocol
- Append new information into existing paragraphs where relevant rather than creating duplicates.
- When a conflict between this file and `REQUIREMENTS.md` occurs, it must be flagged to the user immediately.
