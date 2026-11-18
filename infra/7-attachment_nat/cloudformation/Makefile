# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 7 (1:1 NAT on attachments).
#
# NOTE: the policy in core_network.yaml must match ../baseline.json; CI compares them.
# To deploy a policy of your own, copy the template and pass CORE_TEMPLATE

.PHONY: deploy deploy-cloudwan deploy-workloads deploy-vpn undeploy undeploy-vpn undeploy-workloads undeploy-cloudwan

IDENTIFIER      ?= overlap
NVIRGINIA       ?= us-east-1
IRELAND         ?= eu-west-1
CORE_STACK      ?= core-network-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the generated template:
# copy core_network.yaml, paste your policy under PolicyDocument, then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml

NVIRGINIA_STACK ?= $(IDENTIFIER)-nvirginia
IRELAND_STACK   ?= $(IDENTIFIER)-ireland
VPN_STACK       ?= $(IDENTIFIER)-vpn

# Optional VPN, off by default. CUSTOMER_GATEWAY_IP describes your on-premises VPN device.
CUSTOMER_GATEWAY_IP  ?= 203.0.113.10
CUSTOMER_GATEWAY_ASN ?= 65010
ONPREM_CIDR          ?= 10.10.0.0/16
ONPREM_NAT           ?= 100.66.0.0/16

CORENETWORK_ID  = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region $(NVIRGINIA))
CORENETWORK_ARN = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkArn`].OutputValue' --output text --region $(NVIRGINIA))

deploy: deploy-cloudwan deploy-workloads

deploy-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(NVIRGINIA)

deploy-workloads:
	aws cloudformation deploy --stack-name $(NVIRGINIA_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(NVIRGINIA)
	aws cloudformation deploy --stack-name $(IRELAND_STACK) --template-file workloads.yaml --parameter-overrides CoreNetworkId="$(CORENETWORK_ID)" CoreNetworkArn="$(CORENETWORK_ARN)" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --region $(IRELAND)

deploy-vpn:
	aws cloudformation deploy --stack-name $(VPN_STACK) --template-file vpn.yaml --parameter-overrides Identifier="$(IDENTIFIER)" CoreNetworkId="$(CORENETWORK_ID)" CustomerGatewayIp="$(CUSTOMER_GATEWAY_IP)" CustomerGatewayAsn="$(CUSTOMER_GATEWAY_ASN)" OnPremisesCidr="$(ONPREM_CIDR)" NatCidr="$(ONPREM_NAT)" --no-fail-on-empty-changeset --region $(NVIRGINIA)

undeploy: undeploy-vpn undeploy-workloads undeploy-cloudwan

undeploy-vpn:
	aws cloudformation delete-stack --stack-name $(VPN_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(VPN_STACK) --region $(NVIRGINIA)

undeploy-workloads:
	aws cloudformation delete-stack --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation delete-stack --stack-name $(IRELAND_STACK) --region $(IRELAND)
	aws cloudformation wait stack-delete-complete --stack-name $(NVIRGINIA_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(IRELAND_STACK) --region $(IRELAND)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(NVIRGINIA)
