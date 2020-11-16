# TH3 Server

## Prerequisites

1. [aws credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) setup for CLI

2. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-install)

    **Note** Do NOT install via yum/apt, the version will be too old.

## Blue/Green Env Provisioner

Blue/Green deployments are established via AWS CodePipeline 

(Optional) Prevent vars from being tracked in git:
```bash
git update-index --assume-unchanged init/vars/*
```

(To undo, change above flag to '--no-assume-unchanged')

1. Modify vars located in init/vars/.

2. Perform deployment:

```bash
cd init
./th3_init.sh
```

**NOTE** This script can be run multiple times.

It will provision the following:
- ALB
- ECS cluster
- ECS Fargate service
- CodeDeploy application

## CI/CD

Via [AWS CodePipeline](https://console.aws.amazon.com/codesuite/codepipeline/pipelines/th3/view?region=us-east-1) 
with the included `buildspec.yml`.

As new commits are made to master branch in [Git](https://github.com/nme-tech/th3-jam) CodePipeline downloads the source, 
builds it in CodeBuild, archives to S3, and performs a Blue/Green deployment in ECS Fargate which is toggled via the ALB.

## TODO

- This should be done in Ansible/Terraform. I spent too much time as it is, excuse the seds...
- More documentation
