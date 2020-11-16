#!/bin/bash
# TH3 Blue-Green PaaS
#
# @author Nick Stires <nick@nmetech.com>
# @link https://console.aws.amazon.com/codesuite/codepipeline/pipelines/th3/view?region=us-east-1
#
# Resource: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-blue-green.html
#
# ------------------------------------------------------------------------------

export REPO_ROOT=$(git rev-parse --show-toplevel)

# Fetch vars
for v in ${REPO_ROOT}/init/vars/*; do source $v; done

# Load functions
for f in ${REPO_ROOT}/init/bin-functions/*; do source $f; done

alb_create
ecs_create
cd_create