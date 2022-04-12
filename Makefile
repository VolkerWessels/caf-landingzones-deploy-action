# Internal variables.
SHELL := /bin/bash

# COLORS
NOCOLOR=\033[0m
NC=${NOCOLOR}
RED=\033[0;31m
GREEN=\033[0;32m
ORANGE=\033[0;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
LIGHTGRAY=\033[0;37m
DARKGRAY=\033[1;30m
LIGHTRED=\033[1;31m
LIGHTGREEN=\033[1;32m
YELLOW=\033[1;33m
LIGHTBLUE=\033[1;34m
LIGHTPURPLE=\033[1;35m
LIGHTCYAN=\033[1;36m
WHITE=\033[1;37m

.ONESHELL:
.SHELLFLAGS := -euc -o pipefail
.DELETE_ON_ERROR:
MAKEFLAGS += --silent
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: help info landingzones login logout formatting LANDINGZONE_check _action validate init plan apply destroy tags show list import

help:
	@echo "Please use 'make [<arg1=a> <argN=...>] <target>' where <target> is one of"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z\._-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

info: ## Information about ENVIRONMENT variables and how to use them.
	@echo "Please use '<env> <env> make [<arg1=a> <argN=...>] <target>' where <env> is one of"
	@awk  'BEGIN { FS = "\\s?(\\?=|:=).*###"} /^[a-zA-Z\._-]+.*?###.* / {printf "\033[33m%-28s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

PARALLELISM?='30'### Limit the number of concurrent operation as Terraform walks the graph. Defaults to 30.
RANDOM_LENGTH?='5'### Random string length for azure resource naming. Defaults to 5

_TFVARS_PATH:="$(shell pwd)/.github/tests/config"
TFVARS_PATH?=$(_TFVARS_PATH)
_BASE_DIR:=$(shell dirname $(TFVARS_PATH))

LANDINGZONES_DIR?="$(_BASE_DIR)/landingzones"### Landingzone directory checkout dir. Defaults to 'landingzones/'

ENVIRONMENT := $(shell echo $(ENVIRONMENT) | tr '[:upper:]' '[:lower:]')### Environment name to deploy to.

_PREFIX:=g$(GITHUB_RUN_ID)
PREFIX?=$(_PREFIX)
PREFIX?=$(shell echo $(PREFIX)|tr '[:upper:]' '[:lower:]')### Prefix azure resource naming.

_IMPORT=""
_ADDRESS=""

_TF_VAR_workspace:=tfstate
TF_VAR_workspace?=$(_TF_VAR_workspace)### Terraform workspace. Defaults to`tfstate`.

_TF_LOG:=ERROR
TF_LOG?=$(_TF_LOG)### Terraform logging. Defaults to`ERROR`.

_TF_LOG_PATH:=$(_BASE_DIR)/terraform.log
TF_LOG_PATH?=$(_TF_LOG_PATH)### Terraform log outputfile. Defaults to`./terraform.log`.

_TF_INPUT:="false"
TF_INPUT=?=$(_TF_INPUT)### Causes terraform commands to behave as if the -input=false. Defaults to`false`.

_SPKVURL:=""
SPKVURL?=$(_SPKVURL)### Impersonate keyvault URL. Defaults to none.

_DISABLEVMEXTENSIONS:=""
DISABLEVMEXTENSIONS?=$(_DISABLEVMEXTENSIONS)### Impersonate keyvault URL. Defaults to none.

ifndef SOLUTION
override SOLUTION = "caf_solution"
endif

ifndef TFSTATE
override TFSTATE = $(shell basename $(_LANDINGZONE))
endif

landingzones: ## Install caf-terraform-landingzones
	@echo -e "${LIGHTGRAY}TFVARS_PATH:		$(TFVARS_PATH)${NC}"
	@echo -e "${LIGHTGRAY}LANDINGZONES_DIR:	$(LANDINGZONES_DIR)${NC}"
	if [ ! -d \"$(LANDINGZONES_DIR)\" ]; then \
		echo -e "${GREEN}Installing landingzones (version : $(TF_LZ_BRANCH))${NC}"; \
		git clone --branch $(TF_LZ_BRANCH) $(TF_LZ_GIT) $(LANDINGZONES_DIR); \
		echo -e "${GREEN}Creating symlink for .devcontainer.$$(cd /tf/caf/ && ln -s $(LANDINGZONES_DIR)/.devcontainer .devcontainer)${NC}" ;\
	fi
	if [ "$(DISABLEVMEXTENSIONS)" == "true" ]; then echo -e "${GREEN}Removing vm extensions for speed${NC}" && rm $(LANDINGZONES_DIR)\*_extensions.tf -rf; fi
	echo -e "${GREEN}Landingzones installed (version: $$(cd $(LANDINGZONES_DIR) && git branch --show-current))${NC}"
	echo -e "${CYAN}#### ROVER IMAGE VERSION REQUIRED FOR LANDINGZONES: $$(cat $(LANDINGZONES_DIR)/.devcontainer/docker-compose.yml | yq .services.rover.image) ####${NC}"

login: ## Login to azure using a service principal
	az config set extension.use_dynamic_install=yes_without_prompt;
	@echo -e "${LIGHTGREEN}Azure login using service principal.\n\nAvailable subscriptions:${NC}"
	az login --service-principal --allow-no-subscriptions -u ${ARM_CLIENT_ID} -p=${ARM_CLIENT_SECRET} --tenant ${ARM_TENANT_ID} --query "[?state == 'Enabled'].name" -o table;
	if [ -v ARM_SUBSCRIPTION_ID ]; then \
		echo -e "${LIGHTGREEN}Subscription set!${NC}"; \
		az account set --subscription $$ARM_SUBSCRIPTION_ID;
	elif [ -v ARM_SUBSCRIPTION_NAME ]; then \
		ARM_SUBSCRIPTION_ID=$$(az graph query -q "resourcecontainers | where type == 'microsoft.resources/subscriptions' | where properties.state contains 'enabled'| where name=='$${ARM_SUBSCRIPTION_NAME}' | project subscriptionId" --query "data[].subscriptionId" -o tsv); \
		az account set --subscription "$${ARM_SUBSCRIPTION_ID}"; \
	  	echo -e "${LIGHTGREEN}Subscription set by name '${ARM_SUBSCRIPTION_NAME}'!${NC}"; \
		export ARM_SUBSCRIPTION_ID="$${ARM_SUBSCRIPTION_ID}"
	else \
		echo -e "${RED}No subscription set!${NC}"; exit 1;
	fi
	@echo -e "${LIGHTGREEN}Logged in to $$(az account show --query 'name')${NC}"; \

logout: ## Logout service principal
	@echo -e "${GREEN}Logout service principal${NC}"
	az logout || true
    # Cleanup any service principal session
	unset ARM_TENANT_ID
	unset ARM_SUBSCRIPTION_ID
	unset ARM_SUBSCRIPTION_NAME
	unset ARM_CLIENT_ID
	unset ARM_CLIENT_SECRET

	@echo -e "${GREEN}Azure session closed${NC}"

formatting: ## Run 'terraform fmt -check --recursive' using rover
	terraform fmt -check --recursive $(TFVARS_PATH)

_workspace:
	@echo -e "${GREEN}Create '$(TF_VAR_workspace)' if not exists${NC}"
	/bin/bash -c \
		"/tf/rover/rover.sh -env $(ENVIRONMENT) workspace create $(TF_VAR_workspace)"

_action: _VAR_FOLDERS= $(shell find $(TFVARS_PATH)/level$(_LEVEL)/$(_LANDINGZONE) -type d -print0 | xargs -0 -I '{}' sh -c "printf -- '-var-folder %s \ \n' '{}';" )
_action:
	@echo -e "${LIGHTGRAY}$$(cd $(_BASE_DIR) && pwd)${NC}"
	@echo -e "${GREEN}Terraform $(_ACTION) for '$(_LANDINGZONE) level$(_LEVEL)'${NC}"
	_ACTION=$(_ACTION)
	_LANDINGZONE=$(_LANDINGZONE)
	_PLAN="$(_BASE_DIR)/$(PREFIX)-$${_LANDINGZONE////-}.tfplan"
	_LEVEL="level$(_LEVEL)"
	_VARS=""
	_IMPORT=$(_IMPORT)
	_ADDRESS=$(_ADDRESS)
	_VAR_FOLDERS="$(_VAR_FOLDERS)"
	_PARALLELISM="-parallelism $(PARALLELISM)"
	_SOLUTION="$(_SOLUTION)"
	if [ "$(_LEVEL)" == "0" ]; then _LEVEL="level0 -launchpad"; fi
	if [ "$(_SOLUTION)" == "caf_launchpad" ]; then _LEVEL="$$_LEVEL" && _VARS="'-var random_length=$(RANDOM_LENGTH)' '-var prefix=$(PREFIX)'"; fi
	if [ ! "$(_ACTION)" == "validate" ]; then _ACTION="$(_ACTION) --plan $$_PLAN"; fi
	if [ "$(_ACTION)" == "plan" ] || [ "$(_ACTION)" == "apply" ]; then _ACTION="$(_ACTION) --plan $$_PLAN"; fi
	if [ "$(_ACTION)" == "import" ]; then _ACTION="$(_ACTION)" _VARS="$(_IMPORT) $(_ADDRESS)"; fi
	if [ "$(_ACTION)" == "show" ] || [ "$(_ACTION)" == "list" ]; then _ACTION="state\ $(_ACTION)" _VARS="$(_ADDRESS)" _VAR_FOLDERS="" _PARALLELISM=""; fi
	if [ "$(_ACTION)" == "destroy" ]; then echo -e "${RED} You cannot destroy landingzones using the deploy action, use the caf-landingzones-destroy-action instead ${NC}" && exit; fi
	if [ "$(SPKVURL)" != "" ]; then echo -e "${GREEN} impersonating using $(SPKVURL)${NC}"; _PARALLELISM="$$_PARALLELISM --impersonate-sp-from-keyvault-url $(SPKVURL)"; fi
	exit_code=0; \
	/bin/bash -c \
			"/tf/rover/rover.sh -lz $(LANDINGZONES_DIR)/$$_SOLUTION -a $$_ACTION \
				$$_VAR_FOLDERS \
				-level $$_LEVEL \
				-tfstate $(TFSTATE).tfstate \
				$$_PARALLELISM \
				-env $(ENVIRONMENT) \
				-no-color \
				$$_VARS" || exit_code="$$?" ; \
				if [ "$$exit_code" -eq 2 ]; \
					then echo -e "${GREEN}Plan succeeded with changes${NC}" && true; \
				else \
				  exit $$exit_code; \
				fi

tags: _LEVEL=$(LEVEL)
tags: _LANDINGZONE=$(LANDINGZONE)
tags: _TAGS=$(TAGS)
tags: ## Generate tags.tfvars.json for LANDINGZONE. Usage example: make tags TAGS=$(echo -e "OpCo: foo\nCostCenter: 0000" | base64)  LEVEL=1 LANDINGZONE=gitops
	echo -e "${GREEN}Generating tags.tfvars.json for '$(_LANDINGZONE) level$(_LEVEL)'${NC}"
	_TAGS="$$(echo -n $(_TAGS) | base64 -d )"
	if [ -z "$$_TAGS" ]; then _TAGS="{ LANDINGZONE:, level: }"; fi
	JSON=$$(echo -e "$$_TAGS" | \
			yq -S --indent 2 \
				--arg LANDINGZONE "$(_LANDINGZONE)" \
				--arg level "level$(_LEVEL)" \
				'. + { landingzone: $$LANDINGZONE, level: $$level } | {tags: . }' - \
		)
	echo -e "$$JSON" > $(TFVARS_PATH)/level$(_LEVEL)/$(_LANDINGZONE)/tags.tfvars.json
	echo -e "${GREEN}Succesfully generated:\n\t$(TFVARS_PATH)/level$(_LEVEL)/$(_LANDINGZONE)/tags.tfvars.json${NC}"

validate: _ACTION=validate
validate: _LEVEL=$(LEVEL)
validate: _LANDINGZONE=$(LANDINGZONE)
validate: _SOLUTION=$(SOLUTION)
validate: _action ## Run `terraform validate` using rover. Usage example: make validate LANDINGZONE=add-ons/eslz LEVEL=1

init: _ACTION=init
init: _LEVEL=$(LEVEL)
init: _LANDINGZONE=$(LANDINGZONE)
init: _SOLUTION=$(SOLUTION)
init: _action ## Run `terraform init` using rover. Usage example: make init LANDINGZONE=launchpad LEVEL=0

plan: _ACTION=plan
plan: _LEVEL=$(LEVEL)
plan: _LANDINGZONE=$(LANDINGZONE)
plan: _SOLUTION=$(SOLUTION)
plan: _action ## Run `terraform plan` using rover. Usage example: make plan LANDINGZONE=add-ons/gitops LEVEL=1

apply: _ACTION=apply
apply: _LEVEL=$(LEVEL)
apply: _LANDINGZONE=$(LANDINGZONE)
apply: _SOLUTION=$(SOLUTION)
apply: _action ## Run `terraform apply` using rover. Usage example: make apply LANDINGZONE=networking LEVEL=2

destroy: _ACTION=destroy
destroy: _LEVEL=$(LEVEL)
destroy: _LANDINGZONE=$(LANDINGZONE)"
destroy: _SOLUTION=$(SOLUTION)"
destroy: _action ## Run `terraform destroy` using rover. Usage example: make destroy LANDINGZONE=application LEVEL=4

show: _ACTION=show
show: _LEVEL=$(LEVEL)
show: _LANDINGZONE=$(LANDINGZONE)
show: _ADDRESS=$(ADDRESS)
show: _SOLUTION=$(SOLUTION)"
show: _action ## Run `terraform state show` using rover. Usage example: make show LANDINGZONE=application LEVEL=4 ADDRESS=module.launchpad.module.subscriptions[\\\\\\\"connectivity\\\\\\\"].azurerm_subscription.sub[0]

list: _ACTION=list
list: _LEVEL=$(LEVEL)
list: _LANDINGZONE=$(LANDINGZONE)
list: _ADDRESS=$(ADDRESS)
list: _SOLUTION=$(SOLUTION)"
list: _action ## Run `terraform state list` using rover. Usage example: make show LANDINGZONE=application LEVEL=4 ADDRESS=module.launchpad.module.subscriptions[\\\\\\\"connectivity\\\\\\\"].azurerm_subscription.sub[0]


import: _ACTION=import
import: _LEVEL=$(LEVEL)
import: _LANDINGZONE=$(LANDINGZONE)
import: _IMPORT=$(IMPORT)
import: _ADDRESS=$(ADDRESS)
import: _SOLUTION=$(SOLUTION)"
import: _action ## Run `terraform import` using rover. Usage example: make import LANDINGZONE=launchpad LEVEL=0 IMPORT=module.launchpad.module.subscriptions[\\\\\\\"connectivity\\\\\\\"].azurerm_subscription ADDRESS=/providers/Microsoft.Subscription/aliases/connectivity
