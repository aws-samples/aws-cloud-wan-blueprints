# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy/teardown helpers for infra pattern 6 (Prefix list association).
#
# Three phases, in this order, because a core network policy cannot reference a prefix list alias that does not exist yet:
#   1. deploy-cloudwan     core_network.yaml               policy WITHOUT the alias
#   2. deploy-prefix-list  prefix_list.yaml                prefix list + association
#   3. deploy-policy       core_network_prefix_list.yaml   policy WITH the alias, same stack as 1
#
# Teardown runs in reverse, and reverts the policy first: the association cannot be deleted while a live policy still references its alias.
#
# NOTE: the policy in core_network.yaml must match ../baseline.json, and the one in core_network_prefix_list.yaml must match ../baseline_prefix_list.json; CI compares them.
# To deploy a policy of your own, copy the template and pass CORE_TEMPLATE

.PHONY: deploy deploy-cloudwan deploy-prefix-list deploy-policy outputs undeploy revert-policy undeploy-prefix-list undeploy-cloudwan

IDENTIFIER      ?= prefix-list
OREGON          ?= us-west-2
CORE_STACK      ?= core-network-$(IDENTIFIER)
PL_STACK        ?= prefix-list-$(IDENTIFIER)

# Override to deploy a core network with your own policy without editing the
# generated template: copy core_network.yaml, paste your policy under PolicyDocument,
# then `make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml`.
CORE_TEMPLATE   ?= core_network.yaml
PL_TEMPLATE     ?= core_network_prefix_list.yaml

# The alias the routing policy in core_network_prefix_list.yaml matches on. Change it here
# and you must change it in that template too.
PREFIX_LIST_ALIAS ?= routesfiltered

deploy: deploy-cloudwan deploy-prefix-list deploy-policy

# Phase 1: core network with a policy that does not mention the alias.
deploy-cloudwan:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(OREGON)

# Phase 2: the prefix list and its association with the core network.
deploy-prefix-list: CORENETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CORE_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region $(OREGON))
deploy-prefix-list:
	aws cloudformation deploy --stack-name $(PL_STACK) --template-file prefix_list.yaml --parameter-overrides Identifier="$(IDENTIFIER)" CoreNetworkId="$(CORENETWORK_ID)" PrefixListAlias="$(PREFIX_LIST_ALIAS)" --no-fail-on-empty-changeset --region $(OREGON)

# Phase 3: replace the policy on the SAME stack with the one that references the alias.
deploy-policy:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(PL_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(OREGON)

# Prints the core network and the alias a routing policy matches on.
outputs:
	@aws cloudformation describe-stacks --stack-name $(CORE_STACK) --query 'Stacks[0].Outputs[?OutputKey==`CoreNetworkId`].OutputValue' --output text --region $(OREGON) | sed 's/^/CORENETWORK_ID=/'
	@aws cloudformation describe-stacks --stack-name $(PL_STACK) --query 'Stacks[0].Outputs[?OutputKey==`PrefixListArn`].OutputValue' --output text --region $(OREGON) | sed 's/^/PREFIX_LIST_ARN=/'
	@aws cloudformation describe-stacks --stack-name $(PL_STACK) --query 'Stacks[0].Outputs[?OutputKey==`PrefixListAlias`].OutputValue' --output text --region $(OREGON) | sed 's/^/PREFIX_LIST_ALIAS=/'

undeploy: revert-policy undeploy-prefix-list undeploy-cloudwan

# Put the policy without the alias back, so the association is no longer referenced.
# Deleting an association a live policy still matches on fails.
revert-policy:
	aws cloudformation deploy --stack-name $(CORE_STACK) --template-file $(CORE_TEMPLATE) --parameter-overrides Identifier="$(IDENTIFIER)" --no-fail-on-empty-changeset --region $(OREGON)

undeploy-prefix-list:
	aws cloudformation delete-stack --stack-name $(PL_STACK) --region $(OREGON)
	aws cloudformation wait stack-delete-complete --stack-name $(PL_STACK) --region $(OREGON)

undeploy-cloudwan:
	aws cloudformation delete-stack --stack-name $(CORE_STACK) --region $(OREGON)
	aws cloudformation wait stack-delete-complete --stack-name $(CORE_STACK) --region $(OREGON)
