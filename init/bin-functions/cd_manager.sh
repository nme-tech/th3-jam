#!/bin/bash

# Fetch CodeDeploy details
cd_info() {
  export CD_DEP_ROLE=$(aws iam get-role \
          --role-name ${CD_APP_NAME}-deploy \
          --query "Role.Arn" \
          --output text | grep -v None 2>/dev/null)
  export CD_APP_ID=$(aws deploy get-application \
          --application-name ${CD_APP_NAME} \
          --query "application.applicationName" \
          --output text | grep -v None 2>/dev/null)
  export CD_DEP_GRP_ID=$(aws deploy get-deployment-group \
          --application-name ${CD_APP_NAME} \
          --deployment-group-name ${CD_APP_NAME}-dg \
          --query "deploymentGroupInfo.deploymentGroupId" \
          --output text 2>/dev/null)
}

# Create CodeDeploy resources
cd_create() {
  cd_info

  # Verify CodeDeploy-ECS IAM role
  if [ -z "${CD_DEP_ROLE}" ]; then
    aws iam create-role \
      --role-name ${CD_APP_NAME}-deploy \
      --assume-role-policy-document file://${REPO_ROOT}/init/conf/iam-deploy-role-trust.json >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create CodeDeploy-ECS role. Exiting..."
      exit 1
    fi
    cd_info

    aws iam attach-role-policy \
      --role-name ${CD_APP_NAME}-deploy \
      --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to attach CodeDeploy-ECS policy. Exiting..."
      exit 1
    fi

  else
    echo "[INFO] CodeDeploy-ECS role found: ${CD_DEP_ROLE}"
  fi

  # Verify CodeDeploy application
  if [ -z "${CD_APP_ID}" ]; then
    aws deploy create-application \
      --application-name ${CD_APP_NAME} \
      --compute-platform ECS >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create CodeDeploy application. Exiting..."
      exit 1
    fi
    cd_info
  else
    echo "[INFO] CodeDeploy application found: ${CD_APP_ID}"
  fi

  # Verify CodeDeploy deployment group
  if [ -z "${CD_DEP_GRP_ID}" ]; then
    # Prep template
    cat ${REPO_ROOT}/init/conf/cd-deployment-group.json > /tmp/cd-deployment-group.json
    sed -i "s/REPLACE_APP_NAME/${CD_APP_NAME}/g" /tmp/cd-deployment-group.json
    sed -i "s/REPLACE_ALB_NAME/${ALB_NAME}/g" /tmp/cd-deployment-group.json
    sed -i "s|REPLACE_ALB_LISTENER_ARN|${ALB_LISTENER_ARN}|g" /tmp/cd-deployment-group.json
    sed -i "s|REPLACE_CD_DEP_ROLE|${CD_DEP_ROLE}|g" /tmp/cd-deployment-group.json
    sed -i "s/REPLACE_ECS_NAME/${ECS_NAME}/g" /tmp/cd-deployment-group.json

    aws deploy create-deployment-group \
      --cli-input-json file:///tmp/cd-deployment-group.json >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create CodeDeploy application. Exiting..."
      exit 1
    fi
    cd_info
  else
    echo "[INFO] CodeDeploy application found: ${CD_DEP_GRP_ID}"
  fi

}

RUNNING="$(basename $0)"
if [[ "$RUNNING" == "cd_info" ]]; then
  cd_info "$@"
elif [[ "$RUNNING" == "cd_create" ]]; then
  cd_create "$@"
fi
