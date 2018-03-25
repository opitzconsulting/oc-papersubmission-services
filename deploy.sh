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
#aws cloudformation deploy --template-file ${TEMPLATE_FILE} --parameter-overrides SwaggerS3File=${BUCKET} --stack-name ${STACK_NAME} --capabilities CAPABILITY_IAM
aws cloudformation deploy --template-file ${TEMPLATE_FILE} --parameter-overrides SwaggerS3File=${BUCKET} Name=${NAME} --stack-name ${STACK_NAME} --capabilities CAPABILITY_NAMED_IAM

