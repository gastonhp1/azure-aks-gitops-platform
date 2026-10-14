# ADR-0002: Gateway API with Envoy Gateway instead of ingress-nginx

- Status: accepted
- Date: 2026-10

## Context

The Kubernetes project retired ingress-nginx in March 2026 (no further releases or
security fixes). The `Ingress` API itself is frozen; new traffic features land in
Gateway API, which also separates infrastructure ownership (Gateway) from app
ownership (Routes).

Options considered: Envoy Gateway, Cilium Gateway API (already our CNI data plane),
Application Gateway for Containers (Azure managed), Traefik.

## Decision

Use **Envoy Gateway** with one shared `Gateway` named `public` in
`envoy-gateway-system`:

- The platform owns listeners, TLS (cert-manager, `enableGatewayAPI`) and the
  HTTP→HTTPS redirect.
- Apps attach `HTTPRoute`s from their own namespace, only if the namespace carries
  `platform.gastonhp1.dev/expose: "true"` (namespaces are created by the platform).

## Why not the alternatives

- **Cilium Gateway:** attractive (one fewer component), but AKS-managed Cilium does not
  expose the Gateway API feature set we need, and it couples ingress upgrades to the CNI.
- **AGC:** fully managed but Azure-only; this platform must also run on kind.
- **Traefik:** fine choice; Envoy Gateway won on conformance coverage and on sharing the
  data plane technology most service meshes use.

## Consequences

- Same manifests on kind and AKS.
- Moving an app between clusters only means changing a hostname in its values file.
