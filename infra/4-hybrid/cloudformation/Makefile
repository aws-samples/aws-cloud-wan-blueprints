# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 4 (Hybrid).
#
# NOTE: core_network.yaml is GENERATED from ../baseline.json and must not be edited by
# hand. To deploy a policy of your own, copy it and pass CORE_TEMPLATE - see the
# variable below and README.md.

.PHONY: deploy deploy-cloudwan deploy-workloads undeploy undeploy-workloads undeploy-cloudwan

IDENTIFIER      ?= hybrid
HOME_REGION     ?= us-east-1
NVIRGINIA       ?= us-east-1
IRELAND         ?= eu-west-1
CORE_STACK      ?= core-network-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the
# generated template: copy core_network.yaml, paste your policy under PolicyDocument,
# then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml
NVIRGINIA_STACK ?= $(IDENTIFIER)-nvirginia
IRELAND_STACK   ?= $(IDENTIFIER)-ireland

deploy: deploy-cloudwan deploy-workloads

deploy-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(HOME_REGION)

deploy-workloads: CORENETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region $(HOME_REGION))
deploy-workloads: CORENETWORK_ARN = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkArn`].OutputValue' --output text --region $(HOME_REGION))
deploy-workloads:
	aws cloudformation deploy --stack-name $(NVIRGINIA_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(NVIRGINIA)
	aws cloudformation deploy --stack-name $(IRELAND_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(IRELAND)

undeploy: undeploy-workloads undeploy-cloudwan

undeploy-workloads:
	aws cloudformation delete-stack --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation delete-stack --stack-name $(IRELAND_STACK) --region $(IRELAND)
	aws cloudformation wait stack-delete-complete --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(IRELAND_STACK) --region $(IRELAND)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(HOME_REGION)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(HOME_REGION)
