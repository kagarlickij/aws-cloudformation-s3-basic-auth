#!/bin/bash

### This works for local execution, not CircleCI
# REPO_NAME=$(basename `git rev-parse --show-toplevel`)
# BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
# STACK_NAME=${REPO_NAME}-${BRANCH_NAME}
# echo -e "STACK_NAME=" $STACK_NAME

# if [ "$BRANCH_NAME" != "master" ]; then {
#     echo -e "Deploy works for MASTER branch only, current branch $BRANCH_NAME is not supported"
#     exit 1
# }
# fi

### This works for CircleCI, not local execution
STACK_NAME=${CIRCLE_PROJECT_REPONAME}-${CIRCLE_BRANCH}
AWS_REGION="us-east-1"
AWS_S3_BUCKET="openapi-specifications"
echo -e "STACK_NAME=" $STACK_NAME
echo -e "AWS_REGION="$AWS_REGION
echo -e "AWS_S3_BUCKET="$AWS_S3_BUCKET

function checkCommandExitCode {
    if [ $? -ne 0 ]; then {
        echo -e $1 "command has failed"
        exit 1
    }
    fi
}

echo -e "Checking if CloudFormation stack exists.."
aws cloudformation describe-stacks --region $AWS_REGION --stack-name $STACK_NAME
if [ $? -ne 0 ]; then {
    echo -e "Starting CloudFormation stack create.."
    aws cloudformation create-stack \
        --region $AWS_REGION \
        --capabilities CAPABILITY_NAMED_IAM \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation.template \
        --parameters \
        ParameterKey=BucketName,ParameterValue=$AWS_S3_BUCKET
    checkCommandExitCode "CloudFormation stack create"

    WAIT_RESULT=$(aws cloudformation wait stack-create-complete --region $AWS_REGION --stack-name $STACK_NAME)
    if [ "$WAIT_RESULT" == "Waiter StackCreateComplete failed: Waiter encountered a terminal failure state" ]; then {
        echo -e "CloudFormation stack create has failed"
        aws cloudformation describe-stack-events --region $AWS_REGION --stack-name $STACK_NAME
        exit 1
    }
    fi

    DEPLOY_RESULT=$(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $STACK_NAME | jq --raw-output '.Stacks | .[] | .StackStatus')
    if [ "$DEPLOY_RESULT" != "CREATE_COMPLETE" ]; then {
        echo -e "CloudFormation stack create has failed"
        aws cloudformation describe-stack-events --region $AWS_REGION --stack-name $STACK_NAME
        exit 1
    } else {
        echo -e "CloudFormation stack create has passed successfully"
    }
    fi
} else {
    echo -e "Starting CloudFormation stack update.."
    aws cloudformation update-stack \
        --region $AWS_REGION \
        --capabilities CAPABILITY_NAMED_IAM \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation.template \
        --parameters \
        ParameterKey=BucketName,ParameterValue=$AWS_S3_BUCKET
    checkCommandExitCode "CloudFormation stack update"

    WAIT_RESULT=$(aws cloudformation wait stack-update-complete --region $AWS_REGION --stack-name $STACK_NAME)
    if [ "$WAIT_RESULT" == "Waiter StackCreateComplete failed: Waiter encountered a terminal failure state" ]; then {
        echo -e "CloudFormation stack update has failed"
        aws cloudformation describe-stack-events --region $AWS_REGION --stack-name $STACK_NAME
        exit 1
    }
    fi

    DEPLOY_RESULT=$(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $STACK_NAME | jq --raw-output '.Stacks | .[] | .StackStatus')
    if [ "$DEPLOY_RESULT" != "UPDATE_COMPLETE" ]; then {
        echo -e "CloudFormation stack update has failed"
        aws cloudformation describe-stack-events --region $AWS_REGION --stack-name $STACK_NAME
        exit 1
    } else {
        echo -e "CloudFormation stack update has passed successfully"
    }
    fi
}
fi
