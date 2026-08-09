# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 4 (Hybrid).
#
# NOTE: the policy in core_network.yaml must match ../baseline.json; CI compares them.
# To deploy a policy of your own, copy the template and pass CORE_TEMPLATE

.PHONY: deploy deploy-cloudwan deploy-workloads deploy-hybrid undeploy undeploy-hybrid undeploy-workloads undeploy-cloudwan

IDENTIFIER      ?= hybrid
NVIRGINIA       ?= us-east-1
IRELAND         ?= eu-west-1
CORE_STACK      ?= core-network-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the
# generated template: copy core_network.yaml, paste your policy under PolicyDocument,
# then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml
NVIRGINIA_STACK ?= $(IDENTIFIER)-nvirginia
IRELAND_STACK   ?= $(IDENTIFIER)-ireland
HYBRID_STACK    ?= $(IDENTIFIER)-hybrid

# Hybrid attachments, both off by default. CUSTOMER_GATEWAY_IP describes your
# on-premises VPN device; DXGW_ASN is the Amazon-side ASN of the Direct Connect gateway.
CUSTOMER_GATEWAY_IP  ?= 1.2.3.4
CUSTOMER_GATEWAY_ASN ?= 65010
DXGW_ASN             ?= 65000

deploy: deploy-cloudwan deploy-workloads

deploy-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(NVIRGINIA)

deploy-workloads: CORENETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region $(NVIRGINIA))
deploy-workloads: CORENETWORK_ARN = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkArn`].OutputValue' --output text --region $(NVIRGINIA))
deploy-workloads:
	aws cloudformation deploy --stack-name $(NVIRGINIA_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(NVIRGINIA)
	aws cloudformation deploy --stack-name $(IRELAND_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(IRELAND)

deploy-hybrid: CORENETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region $(NVIRGINIA))
deploy-hybrid:
	aws cloudformation deploy --stack-name $(HYBRID_STACK) --template-file hybrid.yaml --parameter-overrides Identifier="$(IDENTIFIER)" CoreNetworkId="$(CORENETWORK_ID)" CustomerGatewayIp="$(CUSTOMER_GATEWAY_IP)" CustomerGatewayAsn="$(CUSTOMER_GATEWAY_ASN)" DirectConnectGatewayAsn="$(DXGW_ASN)" EdgeLocations="$(NVIRGINIA),$(IRELAND)" --no-fail-on-empty-changeset --region $(NVIRGINIA)

undeploy: undeploy-hybrid undeploy-workloads undeploy-cloudwan

undeploy-hybrid:
	aws cloudformation delete-stack --stack-name $(HYBRID_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(HYBRID_STACK) --region $(NVIRGINIA)

undeploy-workloads:
	aws cloudformation delete-stack --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation delete-stack --stack-name $(IRELAND_STACK) --region $(IRELAND)
	aws cloudformation wait stack-delete-complete --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(IRELAND_STACK) --region $(IRELAND)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(NVIRGINIA)
