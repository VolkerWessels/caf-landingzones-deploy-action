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

.PHONY: help info landingzones login logout formatting solution_check _action validate init plan apply destroy tags

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

_TF_VAR_workspace:=tfstate
TF_VAR_workspace?=$(_TF_VAR_workspace)### Terraform workspace. Defaults to`tfstate`.

landingzones: ## Install caf-terraform-landingzones
	@echo -e "${LIGHTGRAY}TFVARS_PATH:		$(TFVARS_PATH)${NC}"
	@echo -e "${LIGHTGRAY}LANDINGZONES_DIR:	$(LANDINGZONES_DIR)${NC}"
	if [ ! -d \"$(LANDINGZONES_DIR)\" ]; then \
		echo -e "${GREEN}Installing landingzones (version : $(TF_LZ_BRANCH))${NC}"; \
		git clone --branch $(TF_LZ_BRANCH) $(TF_LZ_GIT) $(LANDINGZONES_DIR); \
		echo -e "${GREEN}Creating symlink for .devcontainer.$$(cd /tf/caf/ && ln -s $(LANDINGZONES_DIR)/.devcontainer .devcontainer)${NC}" ;\
	fi
	echo -e "${GREEN}Landingzones installed (version: $$(cd $(LANDINGZONES_DIR) && git branch --show-current))${NC}"
	echo -e "${CYAN}#### ROVER IMAGE VERSION REQUIRED FOR LANDINGZONES: $$(cat $(LANDINGZONES_DIR)/.devcontainer/docker-compose.yml | yq .services.rover.image) ####${NC}"

login: ## Login to azure using a service principal
	@echo -e "${GREEN}Azure login using service principal${NC}"
	az login --service-principal --allow-no-subscriptions -u ${ARM_CLIENT_ID} -p ${ARM_CLIENT_SECRET} --tenant ${ARM_TENANT_ID};
	if [ ! -z "$${ARM_SUBSCRIPTION_ID}" ]; then \
		echo -e "${LIGHTGREEN}Subscription set!${NC}";
		az account set --subscription $$ARM_SUBSCRIPTION_ID; \
	else \
		echo -e "${RED}No subscription set!${NC}"; exit 1;
	fi
	@echo -e "${GREEN}Logged in to $$(az account show --query 'name')${NC}"; \

logout: ## Logout service principal
	@echo -e "${GREEN}Logout service principal${NC}"
	az logout || true
	# Cleaup any service principal session
	unset ARM_TENANT_ID
	unset ARM_SUBSCRIPTION_ID
	unset ARM_CLIENT_ID
	unset ARM_CLIENT_SECRET

	@echo -e "${GREEN}Azure session closed${NC}"

formatting: ## Run 'terraform fmt -check --recursive' using rover
	terraform fmt -check --recursive $(TFVARS_PATH)

_workspace:
	@echo -e "${GREEN}Create '$(TF_VAR_workspace)' if not exists${NC}"
	/bin/bash -c \
		"/tf/rover/rover.sh -env $(ENVIRONMENT) workspace create $(TF_VAR_workspace)"

_action: _ADD_ON = "caf_solution/"
_action: _TFSTATE = $(shell basename $(_SOLUTION))
_action: _VAR_FOLDERS= $(shell find $(TFVARS_PATH)/level$(_LEVEL)/$(_SOLUTION) -type d -print0 | xargs -0 -I '{}' sh -c "printf -- '-var-folder %s \ \n' '{}';" )
_action:
	@echo -e "${LIGHTGRAY}$$(cd $(_BASE_DIR) && pwd)${NC}"
	@echo -e "${GREEN}Terraform $(_ACTION) for '$(_SOLUTION) level$(_LEVEL)'${NC}"
	_ACTION=$(_ACTION)
	_PLAN="$(_BASE_DIR)/$(PREFIX)-$(_SOLUTION).tfplan"
	_ADD_ON=$(_ADD_ON)
	_LEVEL="level$(_LEVEL)"
	_VARS=""
	if [ "$(_LEVEL)" == "0" ]; then _ADD_ON="caf_launchpad" _LEVEL="level0 -launchpad" && _VARS="'-var random_length=$(RANDOM_LENGTH)' '-var prefix=$(PREFIX)'"; fi
	if [ ! "$(_ACTION)" == "validate" ]; then _ACTION="$(_ACTION) --plan $$_PLAN"; fi
	if [ "$(_ACTION)" == "plan" ] || [ "$(_ACTION)" == "apply" ]; then _ACTION="$(_ACTION) --plan $(_BASE_DIR)/$(PREFIX).tfplan"; fi
	if [ "$(_ACTION)" == "destroy" ]; then echo -e "${RED} You cannot destroy landingzones using the deploy action, use the caf-landingzones-destroy-action instead ${NC}" && exit; fi
	if [ -d "$(LANDINGZONES_DIR)/caf_solution/$(_SOLUTION)" ]; then _ADD_ON="caf_solution/$(_SOLUTION)"; fi
	/bin/bash -c \
		"/tf/rover/rover.sh -lz $(LANDINGZONES_DIR)/$$_ADD_ON -a $$_ACTION \
			$(_VAR_FOLDERS) \
			-level $$_LEVEL \
			-tfstate $(_TFSTATE).tfstate \
			-log-severity ERROR \
			-parallelism $(PARALLELISM) \
			-env $(ENVIRONMENT) \
			$$_VARS"

tags: _LEVEL=$(LEVEL)
tags: _SOLUTION=$(SOLUTION)
tags: _TAGS=$(TAGS)
tags: ## Generate tags.tfvars.json for solution. Usage example: make tags TAGS=$(echo -e "OpCo: foo\nCostCenter: 0000" | base64)  LEVEL=1 SOLUTION=gitops
	echo -e "${GREEN}Generating tags.tfvars.json for '$(_SOLUTION) level$(_LEVEL)'${NC}"
	_TAGS="$$(echo -n $(_TAGS) | base64 -d )"
	if [ -z "$$_TAGS" ]; then _TAGS="{ solution:, level: }"; fi
	JSON=$$(echo -e "$$_TAGS" | \
			yq -S --indent 2 \
				--arg solution "$(_SOLUTION)" \
				--arg level "level$(_LEVEL)" \
				'. + { solution: $$solution, level: $$level } | {tags: . }' - \
		)
	echo -e "$$JSON" > $(TFVARS_PATH)/level$(_LEVEL)/$(_SOLUTION)/tags.tfvars.json
	echo -e "${GREEN}Succesfully generated:\n\t$(TFVARS_PATH)/level$(_LEVEL)/$(_SOLUTION)/tags.tfvars.json${NC}"

validate: _ACTION=validate
validate: _LEVEL=$(LEVEL)
validate: _SOLUTION=$(SOLUTION)
validate: _action ## Run `terraform validate` using rover. Usage example: make validate SOLUTION=add-ons/eslz LEVEL=1

init: _ACTION=init
init: _LEVEL=$(LEVEL)
init: _SOLUTION=$(SOLUTION)
init: _action ## Run `terraform init` using rover. Usage example: make init SOLUTION=launchpad LEVEL=0

plan: _ACTION=plan
plan: _LEVEL=$(LEVEL)
plan: _SOLUTION=$(SOLUTION)
plan: _action ## Run `terraform plan` using rover. Usage example: make plan SOLUTION=add-ons/gitops LEVEL=1

apply: _ACTION=apply
apply: _LEVEL=$(LEVEL)
apply: _SOLUTION=$(SOLUTION)
apply: _action ## Run `terraform apply` using rover. Usage example: make apply SOLUTION=networking LEVEL=2

destroy: _ACTION=destroy
destroy: _LEVEL=$(LEVEL)
destroy: _SOLUTION=$(SOLUTION)
destroy: _action ## Run `terraform destroy` using rover. Usage example: make destroy SOLUTION=application LEVEL=4

show: _ACTION=show
show: _LEVEL=$(LEVEL)
show: _SOLUTION=$(SOLUTION)
show: _action ## Run `terraform show` using rover. Usage example: make show SOLUTION=application LEVEL=4
