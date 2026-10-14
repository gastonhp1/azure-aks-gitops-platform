# ADR-0003: No static credentials anywhere

- Status: accepted
- Date: 2026-10

## Decision

| Who | Authenticates to | Mechanism |
|---|---|---|
| Humans | AKS API | Entra ID + Azure RBAC (`local_account_disabled = true`, kubelogin) |
| Kubelet | ACR | Kubelet managed identity with `AcrPull` |
| External Secrets | Key Vault | Workload Identity → `Key Vault Secrets User` |
| cloudsweep | Azure Resource Manager | Workload Identity → `Reader` on the subscription |
| GitHub Actions | ACR | OIDC federated credential on a managed identity, bound to a GitHub **environment** → `AcrPush` |
| Terraform | State storage | Entra ID (`use_azuread_auth`), storage keys disabled |

All federated identities share one module (`modules/federated-identity`) whose only
inputs are an issuer, an exact subject and a list of role assignments.

## Why bind GitHub to an environment and not a branch

A branch subject (`ref:refs/heads/main`) lets any job on `main` assume the identity.
An environment subject only matches jobs that declare that environment, which in turn
can require reviewers and restrict which branches may deploy. Prod push therefore
needs a human approval in GitHub, enforced by Entra, not just by workflow YAML.

## Consequences

- Nothing to rotate, nothing to leak in logs.
- Secret *values* are still created by humans in Key Vault (Secrets Officer role);
  Terraform never sees them, so they never land in state.
