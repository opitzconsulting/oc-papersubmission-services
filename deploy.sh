#!/usr/bin/env bash

: "${STACK_NAME:=$1}"
: "${NAME:=$2}"

if [[ -z ${STACK_NAME} ]]; then
  echo "No Stackname is provided."
  echo "Use: deploy <STACK_NAME> <NAME>"
  exit 2
fi

if [[ -z ${NAME} ]]; then
  echo "No Name is provided."
  echo "Use: deploy <STACK_NAME> <NAME>"
  exit 2
fi

echo "Getting AWS Account ID"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
echo "Using AWS Account with ID: ${AWS_ACCOUNT_ID}"

DEPLOYMENT_BUCKET="${NAME}-${AWS_ACCOUNT_ID}-papersubmission-deployments"
echo "Using ${DEPLOYMENT_BUCKET} for deployment artifacts"
aws s3 mb s3://${DEPLOYMENT_BUCKET} >/dev/null 2>&1

FILENAME=$(cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 32)
echo "swagger.yaml will be uploaded as ${FILENAME}"

TEMPLATE_FILE=packaged-template.yaml
BUCKET="s3://$DEPLOYMENT_BUCKET/$FILENAME"

# Uploading File and using encryption at rest
aws s3 cp swagger.yaml ${BUCKET} --sse

aws cloudformation package --template-file template.yaml --s3-bucket ${DEPLOYMENT_BUCKET} --output-template-file ${TEMPLATE_FILE}
aws cloudformation deploy --template-file ${TEMPLATE_FILE} --parameter-overrides SwaggerS3File=${BUCKET} Name=${NAME} --stack-name ${STACK_NAME} --capabilities CAPABILITY_NAMED_IAM

echo "Updating UserPoolClient with attributes not available with Cloudformation"
USERPOOL_CLIENT_ID=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' --output text)
USERPOOL_ID=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' --output text)
echo "UserPoolId: ${USERPOOL_ID}, UserpoolClientId: ${USERPOOL_CLIENT_ID}"

aws cognito-idp update-user-pool-client --user-pool-id ${USERPOOL_ID} --client-id ${USERPOOL_CLIENT_ID} \
--supported-identity-providers 'COGNITO' \
--callback-urls '["http://localhost:4200/cognito-callback"]' \
--logout-urls '["http://localhost:4200"]' \
--allowed-o-auth-flows 'implicit' \
--allowed-o-auth-scopes 'aws.cognito.signin.user.admin' 'email' 'openid' 'phone'  'profile' \
--allowed-o-auth-flows-user-pool-client

aws cognito-idp delete-user-pool-domain --user-pool-id ${USERPOOL_ID} --domain "ocpapersubmission-${USERPOOL_CLIENT_ID}" >/dev/null 2>&1
aws cognito-idp create-user-pool-domain --user-pool-id ${USERPOOL_ID} --domain "ocpapersubmission-${USERPOOL_CLIENT_ID}"

