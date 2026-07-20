---
name: harness-authoring
description: Create a focused external regression check for high-value behavior or shared contracts.
---

# Harness Authoring

## Use When

- A regression has occurred or is likely to recur.
- Shared behavior can be tested without launching the full product.
- Code review alone cannot prove the required behavior.

## Steps

1. Define one observable contract and its failure signal.
2. Reuse the project's proven test/runtime tools.
3. Keep fixtures synthetic, deterministic and isolated from production.
4. Return exit code `0` only when all assertions pass.
5. Document command, prerequisites, inputs, outputs and scope.
6. Add the command to `harness.config.json` when it should run through the unified entry point.

Do not create an empty Harness merely to satisfy the folder structure.
