# Security model and accepted risks

## Controls

- Identity: see [ADR-0003](adr/0003-no-static-credentials.md).
- Supply chain: see [ADR-0004](adr/0004-admission-verified-images.md).
- Network: Cilium network policy, default-deny ingress for app namespaces; only the
  Gateway and Prometheus namespaces may reach app pods.
- Workloads: Pod Security "restricted" (namespace label + Kyverno), read-only root
  filesystem, all capabilities dropped, seccomp `RuntimeDefault`.
- State: remote state with blob versioning, 30-day soft delete, delete lock, Entra-only auth.
- Repo: gitleaks + detect-private-key in pre-commit; Trivy IaC findings in the Security tab.

## Accepted risks (portfolio scope)

| Finding | Why accepted | How to close |
|---|---|---|
| AKS API server is public | Keeps `kubectl` usable from a laptop without a VPN/bastion | `api_server_access_profile.authorized_ip_ranges` or a private cluster |
| ACR and Key Vault have public endpoints | Same reason; access still requires Entra RBAC | Private endpoints in `snet-private-endpoints` (subnet already reserved) |
| ACR Basic/Standard: no content trust or retention policy | Signatures are verified at admission instead | Premium SKU in prod |
| Key Vault purge protection off in dev | Allows fast destroy/recreate cycles | Already on in prod |
