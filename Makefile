SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ENV            ?= dev
CLUSTER        ?= $(ENV)
TF_DIR         := terraform/envs/$(ENV)
TFSTATE_SA     ?= $(error set TFSTATE_SA to the state storage account name, e.g. make plan TFSTATE_SA=sttfstateghp01)
KUBECONFORM    := kubeconform -strict -summary -ignore-missing-schemas \
                  -schema-location default \
                  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

##@ Local (kind, no Azure needed)
.PHONY: local-up local-down local-forward
local-up: ## Create a kind cluster and bootstrap the full GitOps stack
	kind create cluster --config local/kind-config.yaml
	./scripts/bootstrap-argocd.sh local

local-down: ## Delete the kind cluster
	kind delete cluster --name platform-local

local-forward: ## Expose the Gateway on localhost:8443 (https://demo.127.0.0.1.nip.io:8443)
	kubectl -n envoy-gateway-system port-forward \
	  $$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=public -o name) 8443:443

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

helm-lint: ## Lint and schema-check the demo-api chart for every env
	helm lint charts/demo-api
	@for env in local dev prod; do \
	  echo ">> demo-api ($$env)"; \
	  helm template demo-api charts/demo-api -f gitops/apps/demo-api/values-$$env.yaml | $(KUBECONFORM) || exit 1; \
	done

manifests: ## Build every kustomization and schema-check it
	@for k in $$(find gitops -name kustomization.yaml -exec dirname {} \;); do \
	  echo ">> $$k"; kustomize build $$k | $(KUBECONFORM) || exit 1; \
	done

##@ Help
.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
