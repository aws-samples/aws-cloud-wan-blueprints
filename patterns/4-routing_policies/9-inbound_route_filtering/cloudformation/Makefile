.PHONY: deploy associate-prefix-list undeploy

deploy:
	aws cloudformation deploy \
		--stack-name core-network-inbound-route-filtering \
		--template-file core_network.yaml \
		--no-fail-on-empty-changeset \
		--region us-east-1

associate-prefix-list: CORENETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "core-network-inbound-route-filtering" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region us-east-1)
associate-prefix-list: PREFIX_LIST_ARN = $(shell aws cloudformation describe-stacks --stack-name "core-network-inbound-route-filtering" --query 'Stacks[0].Outputs[?OutputKey == `PrefixListArn`].OutputValue' --output text --region us-east-1)
associate-prefix-list:
	aws networkmanager create-core-network-prefix-list-association \
		--core-network-id "$(CORENETWORK_ID)" \
		--prefix-list-arn "$(PREFIX_LIST_ARN)" \
		--prefix-list-alias "dangerousPrefixes" \
		--region us-east-1

undeploy:
	aws cloudformation delete-stack --stack-name core-network-inbound-route-filtering --region us-east-1
	aws cloudformation wait stack-delete-complete --stack-name core-network-inbound-route-filtering --region us-east-1
