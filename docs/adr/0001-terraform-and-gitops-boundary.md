# ADR-0001: Terraform builds the cluster, Argo CD owns what runs in it

- Status: accepted
- Date: 2026-10

## Context

A common pattern is to install cluster add-ons from Terraform with the `helm` and
`kubernetes` providers. It works on day one and hurts afterwards:

- The providers need a live cluster during `plan`, so a cluster rebuild means a
  two-phase apply and fragile `depends_on` chains.
- Drift inside the cluster (someone edits a Deployment) is invisible until the next plan.
- Kubernetes objects end up in Terraform state, which then holds rendered manifests
  and sometimes secret values.

## Decision

- **Terraform** owns Azure resources only: resource group, network, AKS, ACR,
  Key Vault and identities (including federated credentials).
- **Argo CD** owns every Kubernetes object, including its own installation
  (`gitops/addons/argocd.yaml`). It is installed once with Helm by
  `scripts/bootstrap-argocd.sh`, which then applies the app-of-apps root.
- The only values that cross the boundary are non-secret identifiers
  (client IDs, vault URL, ACR login server). `make configure` renders them from
  `terraform output` into `gitops/clusters/<env>/`, and they are committed.

## Consequences

- A cluster can be destroyed and recreated; `make argocd` brings back the full state from Git.
- Drift is detected and reverted continuously (`selfHeal: true`).
- There is one manual step after the first apply (`make configure` + commit). That is
  deliberate: the identifiers are reviewed in a PR before the cluster uses them.
