# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 2 (Inspection).
#
# THREE-PHASE DEPLOY. A `send-to` / `send-via` action references a network function
# group that has no attachments until the workload stacks exist - and the baseline uses
# dual-hop, which needs an inspection attachment in every Region. So the core network is
# created without service insertion, the workloads are deployed, and the core network is
# then updated with the full policy:
#
#   1. deploy-base-policy   core network WITHOUT service insertion  (base_policy.yaml)
#   2. deploy-workloads     VPCs, inspection VPCs, firewalls        (workloads.yaml)
#   3. update-cloudwan      core network WITH service insertion     (core_network.yaml)
#
# `make deploy` runs all three in order. Terraform does not need this - its dependency
# graph handles the ordering inside a single apply.
#
# NOTE: base_policy.yaml and core_network.yaml are both GENERATED from ../baseline.json
# by tools/sync_cfn_policy.py. To change the policy, edit baseline.json and regenerate.

.PHONY: deploy deploy-base-policy deploy-workloads update-cloudwan \
        undeploy undeploy-workloads undeploy-cloudwan

IDENTIFIER      ?= inspection
HOME_REGION     ?= us-east-1
NVIRGINIA       ?= us-east-1
IRELAND         ?= eu-west-1
CORE_STACK      ?= core-network-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the
# generated template: copy core_network.yaml, paste your policy under PolicyDocument,
# then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml
BASE_TEMPLATE   ?= base_policy.yaml
NVIRGINIA_STACK ?= $(IDENTIFIER)-nvirginia
IRELAND_STACK   ?= $(IDENTIFIER)-ireland

deploy: deploy-base-policy deploy-workloads update-cloudwan

# Phase 1 - core network without service insertion.
deploy-base-policy:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(BASE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(HOME_REGION)

# Phase 2 - workloads, inspection VPCs, firewalls, and the Cloud WAN attachments.
deploy-workloads: CORENETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region $(HOME_REGION))
deploy-workloads: CORENETWORK_ARN = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkArn`].OutputValue' --output text --region $(HOME_REGION))
deploy-workloads:
	aws cloudformation deploy --stack-name $(NVIRGINIA_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(NVIRGINIA)
	aws cloudformation deploy --stack-name $(IRELAND_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(IRELAND)

# Phase 3 - add service insertion now that the inspection attachments exist.
update-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(HOME_REGION)

undeploy: undeploy-workloads undeploy-cloudwan

undeploy-workloads:
	aws cloudformation delete-stack --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation delete-stack --stack-name $(IRELAND_STACK) --region $(IRELAND)
	aws cloudformation wait stack-delete-complete --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(IRELAND_STACK) --region $(IRELAND)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(HOME_REGION)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(HOME_REGION)
