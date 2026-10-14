# Cost estimates

Rough monthly figures for `brazilsouth`, pay-as-you-go, running 24/7, as of late 2026.
Brazil South is noticeably more expensive than US regions; verify with the
[Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) before applying.

## dev (~ USD 120–140 / month)

| Item | Sizing | Approx. |
|---|---|---|
| AKS control plane | Free tier | 0 |
| Nodes | 1 × Standard_D2ads_v5 (autoscale to 3) | ~100 |
| Load balancer + public IP | Standard | ~22 |
| ACR | Basic | ~5 |
| Key Vault | operations only | < 1 |
| Log Analytics | disabled (in-cluster Prometheus) | 0 |

**Portfolio tip:** run `make destroy ENV=dev` when you are done. A full rebuild is
`make apply` + `make argocd` (~15 min) because all in-cluster state lives in Git.
Running only during demos costs a few dollars a day.

## prod (~ USD 650–800 / month)

| Item | Sizing | Approx. |
|---|---|---|
| AKS control plane | Standard tier (uptime SLA) | ~73 |
| System pool | 3 × D2ads_v5, zones 1-3 | ~300 |
| Apps pool | 2–6 × D4ads_v5 | ~400 at the minimum of 2 |
| Container Insights | 1 GB/day cap | ~70 |
| ACR | Standard | ~20 |

Main levers: Spot for the apps pool (`user_pool_spot = true`, for interruptible
workloads), reservations or savings plans for the system pool, and the Log Analytics
daily cap.

The [cloudsweep](https://github.com/gastonhp1/cloudsweep) CronJob running on this
platform reports orphaned disks, idle public IPs and untagged resources weekly.
