# Nested Fence — Feature Plan

> REQUIRED EXECUTOR: /cogniva-dev:execute-feature Nested/Nested

**Goal:** exercise length-aware fence nesting (a 4-backtick fence wrapping a 3-backtick example).

## Task 1: Finished task whose body nests a 4-backtick fence around a 3-backtick example

- [x] **Step 1:** show fenced markdown that itself contains an inner fenced block:
      ````markdown
      Here is an example block with an inner fence:
      ```
      - [ ] this unchecked box is an EXAMPLE inside the inner fence (must be ignored)
      ```
      - [ ] another example box, still inside the OUTER 4-backtick fence (must be ignored)
      ````
- [x] **Step 2:** commit it.

## Task 2: Genuinely unfinished

- [ ] **Step 1:** a real, non-fenced unchecked box — keeps this task not done.
