# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 5 (Multi-account).
#
# NOTE: the policy in core_network.yaml must match ../baseline.json; CI compares them.
# To deploy a policy of your own, copy the template and pass CORE_TEMPLATE

.PHONY: deploy deploy-cloudwan deploy-share outputs undeploy undeploy-share undeploy-cloudwan

IDENTIFIER      ?= multi-account
OREGON          ?= us-west-2
NVIRGINIA       ?= us-east-1
CORE_STACK      ?= core-network-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the
# generated template: copy core_network.yaml, paste your policy under PolicyDocument,
# then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml
SHARE_STACK     ?= core-network-share-$(IDENTIFIER)

# Who to share the core network with. PRINCIPAL_TYPE is account, organizational_unit or
# organization; PRINCIPAL is a 12-digit account ID or an AWS Organizations ARN.
PRINCIPAL_TYPE  ?= account

deploy: deploy-cloudwan deploy-share

deploy-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(OREGON)

deploy-share: CORENETWORK_ARN = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkArn`].OutputValue' --output text --region $(OREGON))
deploy-share:
ifndef PRINCIPAL
	$(error PRINCIPAL is required. Usage: make deploy PRINCIPAL=111122223333 [PRINCIPAL_TYPE=account|organizational_unit|organization])
endif
	aws cloudformation deploy --stack-name $(SHARE_STACK) --template-file ram_share.yaml --parameter-overrides Identifier="$(IDENTIFIER)" CoreNetworkArn="$(CORENETWORK_ARN)" PrincipalType="$(PRINCIPAL_TYPE)" Principal="$(PRINCIPAL)" --no-fail-on-empty-changeset --region $(NVIRGINIA)

# Prints what the spoke accounts need to create their attachments.
outputs:
	@aws cloudformation describe-stacks --stack-name $(CORE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`CoreNetworkId`].OutputValue' --output text --region $(OREGON) | sed 's/^/CORENETWORK_ID=/'
	@aws cloudformation describe-stacks --stack-name $(CORE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`CoreNetworkArn`].OutputValue' --output text --region $(OREGON) | sed 's/^/CORENETWORK_ARN=/'
	@aws cloudformation describe-stacks --stack-name $(SHARE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`ResourceShareArn`].OutputValue' --output text --region $(NVIRGINIA) | sed 's/^/RESOURCE_SHARE_ARN=/'

# Run only AFTER every spoke account has deleted its attachments. A core network with attachments from a spoke account cannot be deleted.
undeploy: undeploy-share undeploy-cloudwan

undeploy-share:
	aws cloudformation delete-stack --stack-name $(SHARE_STACK) --region $(NVIRGINIA)
	aws cloudformation wait stack-delete-complete --stack-name $(SHARE_STACK) --region $(NVIRGINIA)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(OREGON)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(OREGON)
