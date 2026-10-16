SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ENV            ?= dev
CLUSTER        ?= $(ENV)
TF_DIR         := terraform/envs/$(ENV)
TFSTATE_SA     ?= $(error set TFSTATE_SA to the state storage account name, e.g. make plan TFSTATE_SA=sttfstateghp01)
KUBECONFORM    := kubeconform -strict -summary -ignore-missing-schemas \
                  -schema-location default \
                  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
# Unconfigured envs still carry placeholders that fail schema patterns (e.g.
# Gateway hostnames); swap in well-formed dummies for validation only.
FILL_PLACEHOLDERS := sed -E \
                  -e 's/__DOMAIN__/example.com/g; s/PLACEHOLDER_HOSTNAME/demo.example.com/g' \
                  -e 's/(__ACME_EMAIL__|PLACEHOLDER_ACME_EMAIL)/ops@example.com/g' \
                  -e 's|(__VAULT_URL__\|PLACEHOLDER_VAULT_URL)|https://kv-example.vault.azure.net/|g' \
                  -e 's/__ACR_LOGIN_SERVER__/acrexample.azurecr.io/g' \
                  -e 's/__[A-Z_]+_ID__/00000000-0000-0000-0000-000000000000/g'

##@ Local (kind, no Azure needed)
.PHONY: local-up local-down local-forward lan-forward
local-up: ## Create a kind cluster and bootstrap the full GitOps stack
	kind create cluster --config local/kind-config.yaml
	./scripts/bootstrap-argocd.sh local

local-down: ## Delete the kind cluster
	kind delete cluster --name platform-local

FORWARD_ADDRESS ?= 127.0.0.1
LAN_IP          ?= $(shell ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($$i=="src") print $$(i+1)}')

# kubectl port-forward exits as soon as the server resets one connection (any
# browser triggers it sooner or later), so it is restarted in a loop. Ctrl+C stops it.
local-forward: ## Expose the Gateway on localhost:8443 (https://demo. / https://pharmatrace.127.0.0.1.nip.io:8443)
	@trap 'exit 130' INT TERM; while true; do \
	  kubectl -n envoy-gateway-system port-forward --address $(FORWARD_ADDRESS) \
	    $$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=public -o name) 8443:443 \
	    | grep --line-buffered -v '^Handling connection'; \
	  echo ">> port-forward dropped, restarting"; sleep 1; \
	done

lan-forward: ## Like local-forward, also on this PC's LAN IP (https://pharmatrace.<LAN_IP>.nip.io:8443)
	@test -n "$(LAN_IP)" || { echo "could not detect the LAN IP, pass LAN_IP=..."; exit 1; }
	@echo ">> from the LAN: https://pharmatrace.$(LAN_IP).nip.io:8443 (the route needs that hostname in values-local)"
	$(MAKE) local-forward FORWARD_ADDRESS=127.0.0.1,$(LAN_IP)

##@ Local (minikube, no Azure needed)
MINIKUBE_PROFILE ?= platform-local
GOLDEN_PATH      ?= ../secure-cicd-golden-path
PHARMATRACE      ?= ../Pharmatrace
PHARMATRACE_UI   ?= ../PharmaTrace-UI
PHARMATRACE_TAG  ?= $(shell awk '/^appVersion:/{gsub(/"/,"",$$2); print $$2}' charts/pharmatrace/Chart.yaml)
DEMO_IMAGE       ?= $(shell awk '/repository:/{r=$$2} /tag:/{gsub(/"/,"",$$2); t=$$2} END{print r":"t}' gitops/apps/demo-api/values-local.yaml)

.PHONY: minikube-up minikube-down minikube-image minikube-pharmatrace
minikube-up: ## Create a minikube cluster and bootstrap the full GitOps stack
	minikube start -p $(MINIKUBE_PROFILE) --driver=docker --kubernetes-version=stable --cpus=4 --memory=8g
	./scripts/bootstrap-argocd.sh local

minikube-down: ## Delete the minikube cluster
	minikube delete -p $(MINIKUBE_PROFILE)

minikube-image: ## Offline: build demo-api from GOLDEN_PATH into minikube (only used while values-local has no digest)
	$(MAKE) -C $(GOLDEN_PATH) image IMAGE=$(DEMO_IMAGE)
	minikube -p $(MINIKUBE_PROFILE) image load $(DEMO_IMAGE)

minikube-pharmatrace: ## Offline: build the PharmaTrace images (chain, api, ui) from the sibling repos into minikube
	docker build -t pharmatrace/chain:$(PHARMATRACE_TAG) $(PHARMATRACE)
	docker build -t pharmatrace/backend:$(PHARMATRACE_TAG) -f $(PHARMATRACE)/backend/Dockerfile $(PHARMATRACE)
	docker build -t pharmatrace/ui:$(PHARMATRACE_TAG) $(PHARMATRACE_UI)
	minikube -p $(MINIKUBE_PROFILE) image load --overwrite pharmatrace/chain:$(PHARMATRACE_TAG) pharmatrace/backend:$(PHARMATRACE_TAG) pharmatrace/ui:$(PHARMATRACE_TAG)
	-kubectl -n pharmatrace rollout restart deploy

##@ Azure infrastructure
.PHONY: bootstrap init plan apply destroy configure argocd
bootstrap: ## One-time: create the remote state storage (local state)
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply

init: ## terraform init for ENV
	terraform -chdir=$(TF_DIR) init -backend-config="storage_account_name=$(TFSTATE_SA)"

plan: init ## terraform plan for ENV
	terraform -chdir=$(TF_DIR) plan -out=tfplan

apply: ## Apply the saved plan for ENV
	terraform -chdir=$(TF_DIR) apply tfplan

destroy: init ## Tear down ENV (asks for confirmation)
	terraform -chdir=$(TF_DIR) destroy

configure: ## Render gitops placeholders from terraform outputs (needs DOMAIN, ACME_EMAIL)
	./scripts/configure-cluster.sh $(ENV)

argocd: ## Install Argo CD on the current kube-context and point it at CLUSTER
	./scripts/bootstrap-argocd.sh $(CLUSTER)

##@ Quality
.PHONY: lint fmt tf-validate helm-lint manifests
lint: fmt tf-validate helm-lint manifests ## Everything CI runs

fmt: ## terraform fmt check
	terraform fmt -check -recursive terraform

tf-validate: ## terraform validate every root module (no backend)
	@for d in terraform/bootstrap terraform/envs/dev terraform/envs/prod; do \
	  echo ">> $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; \
	done
	tflint --recursive --config "$$(pwd)/.tflint.hcl"

helm-lint: ## Lint and schema-check the charts for every env they have values for
	helm lint charts/demo-api
	helm lint charts/pharmatrace -f gitops/apps/pharmatrace/values-local.yaml
	@for env in local dev prod; do \
	  echo ">> demo-api ($$env)"; \
	  helm template demo-api charts/demo-api -f gitops/apps/demo-api/values-$$env.yaml | $(FILL_PLACEHOLDERS) | $(KUBECONFORM) || exit 1; \
	done
	@echo ">> pharmatrace (local)"
	@helm template pharmatrace charts/pharmatrace -f gitops/apps/pharmatrace/values-local.yaml | $(KUBECONFORM)

manifests: ## Build every kustomization and schema-check it
	@for k in $$(find gitops -name kustomization.yaml -exec dirname {} \;); do \
	  echo ">> $$k"; kustomize build $$k | $(FILL_PLACEHOLDERS) | $(KUBECONFORM) || exit 1; \
	done

##@ Help
.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
