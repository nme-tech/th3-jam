#!/bin/bash

# Fetch ALB details
alb_info() {
  export ALB_SECURITY_GROUP=$(aws ec2 describe-security-groups \
          --filters Name=group-name,Values=${ALB_NAME} \
          --query "SecurityGroups[*].GroupId" \
          --output text 2>/dev/null)
  export ALB_ARN=$(aws elbv2 describe-load-balancers \
          --names "${ALB_NAME}" \
          --query "LoadBalancers[*].LoadBalancerArn" \
          --output text 2>/dev/null)
  export ALB_BLU_TAR_GRP_ARN=$(aws elbv2 describe-target-groups \
          --names ${ALB_NAME}-blue-target-group \
          --query "TargetGroups[*].TargetGroupArn" \
          --output text 2>/dev/null)
  export ALB_GRN_TAR_GRP_ARN=$(aws elbv2 describe-target-groups \
          --names ${ALB_NAME}-green-target-group \
          --query "TargetGroups[*].TargetGroupArn" \
          --output text 2>/dev/null)
  export ALB_LISTENER_ARN=$(aws elbv2 describe-listeners \
          --load-balancer-arn ${ALB_ARN} \
          --query "Listeners[*].ListenerArn" \
          --output text 2>/dev/null)
}

# Create ALB
alb_create() {
  alb_info

  # Verify ALB SG exists
  if [ -z "${ALB_SECURITY_GROUP}" ]; then
    echo "[INFO] ALB Security Group not found, creating..."
    aws ec2 create-security-group \
      --group-name ${ALB_NAME} \
      --description "TH3 Server ALB" \
      --vpc-id ${VPC_ID} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ALB Security Group. Exiting..."
      exit 1
    fi

    alb_info

    echo "[INFO] Setting ingress..."
    aws ec2 authorize-security-group-ingress \
      --group-id ${ALB_SECURITY_GROUP} \
      --protocol tcp \
      --port 80 \
      --cidr 0.0.0.0/0 >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to set ALB Security Group ingress. Exiting..."
      exit 1
    fi

  else
    echo "[INFO] ALB Security Group found: ${ALB_SECURITY_GROUP}"
  fi

  # Create ALB
  if [ -z "${ALB_ARN}" ]; then
    aws elbv2 create-load-balancer \
      --name ${ALB_NAME} \
      --subnets ${VPC_SUBNETS} \
      --security-groups ${ALB_SECURITY_GROUP} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ALB. Exiting..."
      exit 1
    fi
    alb_info
  else
    echo "[INFO] ALB found: ${ALB_ARN}"
  fi

  # Verify ALB 'blue' Target Group
  if [ -z "${ALB_BLU_TAR_GRP_ARN}" ]; then
    aws elbv2 create-target-group \
      --name ${ALB_NAME}-blue-target-group \
      --protocol HTTP \
      --port 8080 \
      --health-check-port 8080 \
      --health-check-path /version \
      --target-type ip \
      --vpc-id ${VPC_ID} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ALB target group. Exiting..."
      exit 1
    fi
    alb_info
  else
    echo "[INFO] ALB 'blue' target group found: ${ALB_BLU_TAR_GRP_ARN}"
  fi

  # Verify ALB 'green' Target Group
  if [ -z "${ALB_GRN_TAR_GRP_ARN}" ]; then
    aws elbv2 create-target-group \
      --name ${ALB_NAME}-green-target-group \
      --protocol HTTP \
      --port 8080 \
      --health-check-port 8080 \
      --health-check-path /version \
      --target-type ip \
      --vpc-id ${VPC_ID} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ALB target group. Exiting..."
      exit 1
    fi
    alb_info
  else
    echo "[INFO] ALB 'green' target group found: ${ALB_GRN_TAR_GRP_ARN}"
  fi

  # Verify ALB Listener
  if [ -z "${ALB_LISTENER_ARN}" ]; then
    aws elbv2 create-listener \
      --load-balancer-arn ${ALB_ARN} \
      --protocol HTTP \
      --port 80 \
      --default-actions Type=forward,TargetGroupArn=${ALB_BLU_TAR_GRP_ARN} >/dev/null
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to create ALB listener. Exiting..."
      exit 1
    fi
    alb_info
  else
    echo "[INFO] ALB listener found: ${ALB_LISTENER_ARN}"
  fi

}

RUNNING="$(basename $0)"
if [[ "$RUNNING" == "alb_info" ]]; then
  alb_info "$@"
elif [[ "$RUNNING" == "alb_create" ]]; then
  alb_create "$@"
fi
