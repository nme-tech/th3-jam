#!/bin/bash

# Fetch ALB details
ecs_info() {
  export ECS_CLUSTER_STATE=$(aws ecs describe-clusters \
          --cluster ${ECS_NAME} \
          --query "clusters[*].status" \
          --output text 2>/dev/null)
  export ECS_ARN=$(aws ecs describe-clusters \
          --cluster ${ECS_NAME} \
          --query "clusters[*].clusterArn" \
          --output text 2>/dev/null)
  export ECS_EXE_ROLE=$(aws iam get-role \
          --role-name ${ECS_NAME}-task-exe \
          --query "Role.Arn" \
          --output text | grep -v None 2>/dev/null)
  export ECS_TASK_ARN=$(aws ecs describe-tasks \
          --cluster ${ECS_NAME} \
          --tasks ${ECS_TASK_NAME} \
          --query "tasks[*].taskArn" \
          --output text 2>/dev/null)
  export ECS_SECURITY_GROUP=$(aws ec2 describe-security-groups \
          --filters Name=group-name,Values=${ECS_NAME} \
          --query "SecurityGroups[*].GroupId" \
          --output text 2>/dev/null)
  export ECS_SERVICE_ARN=$(aws ecs list-services \
          --cluster ${ECS_NAME} \
          --query "serviceArns[*]" \
          --output text 2>/dev/null)
}

# Create ECS resources
ecs_create() {
  ecs_info

  # Verify ECS cluster exists
  if [ -z "${ECS_ARN}" ] || [[ "${ECS_CLUSTER_STATE}" != "ACTIVE" ]]; then
    aws ecs create-cluster \
      --cluster-name ${ECS_NAME} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ECS cluster. Exiting..."
      exit 1
    fi
    ecs_info
  else
    echo "[INFO] ECS cluster found: ${ECS_ARN}"
  fi
  
  # Verify ECS execution IAM role
  if [ -z "${ECS_EXE_ROLE}" ]; then
    aws iam create-role \
      --role-name ${ECS_NAME}-task-exe \
      --assume-role-policy-document file://${REPO_ROOT}/init/conf/iam-ecs-role-trust.json >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ECS IAM execution role. Exiting..."
      exit 1
    fi
    ecs_info

    aws iam attach-role-policy \
      --role-name ${ECS_NAME}-task-exe \
      --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to attach ECS execution policy. Exiting..."
      exit 1
    fi

  else
    echo "[INFO] ECS IAM execution role found: ${ECS_EXE_ROLE}"
  fi

  # Verify ECS task definition exists
  if [ -z "${ECS_TASK_ARN}" ]; then
    aws ecs register-task-definition \
      --execution-role-arn ${ECS_EXE_ROLE} \
      --cli-input-json file://${REPO_ROOT}/init/conf/ecs-task-def.json >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to register task definition. Exiting..."
      exit 1
    fi
    ecs_info
  else
    echo "[INFO] ECS task definition found: ${ECS_TASK_ARN}"
  fi

  # Verify ALB SG exists
  if [ -z "${ECS_SECURITY_GROUP}" ]; then
    echo "[INFO] ECS Security Group not found, creating..."
    aws ec2 create-security-group \
      --group-name ${ECS_NAME} \
      --description "TH3 Server ECS" \
      --vpc-id ${VPC_ID} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ECS Security Group. Exiting..."
      exit 1
    fi

    ecs_info

    echo "[INFO] Setting ingress..."
    aws ec2 authorize-security-group-ingress \
      --group-id ${ECS_SECURITY_GROUP} \
      --protocol tcp \
      --port 8080 \
      --source-group ${ALB_SECURITY_GROUP} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to set ECS Security Group ingress. Exiting..."
      exit 1
    fi

  else
    echo "[INFO] ECS Security Group found: ${ECS_SECURITY_GROUP}"
  fi

  # Verify ECS service exists
  if [ -z "${ECS_SERVICE_ARN}" ]; then
    VPC_SUBNETS_FORMAT=$(echo ${VPC_SUBNETS} | sed 's/ /,/')
    aws ecs create-service \
      --cluster ${ECS_NAME} \
      --service-name th3-server \
      --task-definition th3-server \
      --load-balancers \
        "targetGroupArn=${ALB_BLU_TAR_GRP_ARN},containerName=th3-srv,containerPort=8080" \
      --launch-type FARGATE \
      --deployment-controller type=CODE_DEPLOY \
      --scheduling-strategy REPLICA \
      --platform-version LATEST \
      --network-configuration \
        "awsvpcConfiguration={subnets=[${VPC_SUBNETS_FORMAT}],securityGroups=[${ECS_SECURITY_GROUP}],assignPublicIp=ENABLED}" \
      --desired-count 1 >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ECS service. Exiting..."
      exit 1
    fi
    ecs_info
  else
    echo "[INFO] ECS service found: ${ECS_SERVICE_ARN}"
  fi

}

RUNNING="$(basename $0)"
if [[ "$RUNNING" == "ecs_info" ]]; then
  ecs_info "$@"
elif [[ "$RUNNING" == "ecs_create" ]]; then
  ecs_create "$@"
fi
