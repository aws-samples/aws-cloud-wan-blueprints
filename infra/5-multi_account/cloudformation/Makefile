# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 5 (Multi-account).
#
# Everything here runs in the NETWORKING account. The spoke account creates its own VPC
# and Cloud WAN attachment using the CoreNetworkId / CoreNetworkArn outputs - any other
# pattern's workload template works, pointed at the shared core network.
#
# NOTE: core_network.yaml is GENERATED from ../baseline.json and must not be edited by
# hand. To deploy a policy of your own, copy it and pass CORE_TEMPLATE - see the
# variable below and README.md.

.PHONY: deploy deploy-cloudwan deploy-share outputs undeploy undeploy-share undeploy-cloudwan

IDENTIFIER      ?= multi-account
HOME_REGION     ?= us-east-1
CORE_STACK      ?= core-network-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the
# generated template: copy core_network.yaml, paste your policy under PolicyDocument,
# then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml
SHARE_STACK     ?= core-network-share-$(IDENTIFIER)
ALLOW_EXTERNAL  ?= false

deploy: deploy-cloudwan deploy-share

deploy-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(HOME_REGION)

deploy-share: CORENETWORK_ARN = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkArn`].OutputValue' --output text --region $(HOME_REGION))
deploy-share:
ifndef SPOKE_PRINCIPALS
	$(error SPOKE_PRINCIPALS is required. Usage: make deploy SPOKE_PRINCIPALS="111122223333[,222233334444]")
endif
	aws cloudformation deploy --stack-name $(SHARE_STACK) --template-file ram_share.yaml --parameter-overrides Identifier="$(IDENTIFIER)" CoreNetworkArn="$(CORENETWORK_ARN)" SpokePrincipals="$(SPOKE_PRINCIPALS)" AllowExternalPrincipals="$(ALLOW_EXTERNAL)" --no-fail-on-empty-changeset --region $(HOME_REGION)

# Prints what the spoke accounts need to create their attachments.
outputs:
	@aws cloudformation describe-stacks --stack-name $(CORE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`CoreNetworkId`].OutputValue' --output text --region $(HOME_REGION) | sed 's/^/CORENETWORK_ID=/'
	@aws cloudformation describe-stacks --stack-name $(CORE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`CoreNetworkArn`].OutputValue' --output text --region $(HOME_REGION) | sed 's/^/CORENETWORK_ARN=/'
	@aws cloudformation describe-stacks --stack-name $(SHARE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`ResourceShareArn`].OutputValue' --output text --region $(HOME_REGION) | sed 's/^/RESOURCE_SHARE_ARN=/'

# Run only AFTER every spoke account has deleted its attachments. A core network with
# attachments from another account cannot be deleted.
undeploy: undeploy-share undeploy-cloudwan

undeploy-share:
	aws cloudformation delete-stack --stack-name $(SHARE_STACK) --region $(HOME_REGION)
	aws cloudformation wait stack-delete-complete --stack-name $(SHARE_STACK) --region $(HOME_REGION)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(HOME_REGION)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(HOME_REGION)
