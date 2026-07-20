---
name: adversarial-review
description: Review a change for bugs, regressions, scope drift and missing verification before completion.
---

# Adversarial Review

## Steps

1. Inspect the actual diff and changed-file status.
2. Compare behavior with the request, PRD, accepted ADR and existing contracts.
3. Trace shared callers, boundary conditions, failure states and recovery paths.
4. Check whether each completion claim has matching evidence.
5. Lead with findings ordered by severity and precise file references.

Do not treat formatting preferences as defects. If no issue is found, state remaining test gaps or residual risk.
