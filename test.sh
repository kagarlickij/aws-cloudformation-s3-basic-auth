#!/bin/bash

echo -e "Starting CloudFormation Linter.."
cfn-lint
if [ $? -ne 0 ]; then {
    echo -e "CloudFormation Linter has failed"
    exit 1
} else {
    echo -e "CloudFormation Linter has passed successfully"
}
fi
