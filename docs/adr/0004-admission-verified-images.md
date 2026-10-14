# ADR-0004: Verify image signatures at admission

- Status: accepted
- Date: 2026-10

## Context

Scanning and signing in CI only help if the cluster refuses what CI did not produce.
Otherwise anyone with push access to the registry, or a typo in a values file,
can run an arbitrary image.

## Decision

Kyverno `verifyImages` on every Pod whose image comes from our registries:

- Keyless attestor: issuer `https://token.actions.githubusercontent.com`, subject pinned to
  `gastonhp1/secure-cicd-golden-path/.github/workflows/reusable-container.yml` on `main`
  or a `v*` tag. A signature made from a fork, a feature branch or another workflow fails.
- `mutateDigest: true`: tags are resolved and rewritten to digests at admission.
- `failureAction`: **Audit** in dev and local (see violations without blocking work),
  **Enforce** in prod (patched in `gitops/clusters/prod/config`).

Pod Security "restricted" is applied the same way (audit → enforce).

## Consequences

- Admission depends on Rekor/Fulcio reachability; `webhookTimeoutSeconds: 30` and
  Kyverno's verification cache keep that acceptable. Air-gapped clusters would need a
  key-based attestor instead.
- Policy reports (`kubectl get policyreport -A`) are the audit trail in dev.
