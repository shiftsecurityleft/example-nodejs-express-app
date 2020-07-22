# Infrapipe - Example App (Nodejs/Express)

Include a sample Terraform which creates encrypted and private S3 bucket on AWS with logging enabled.

## Quick Start Guide

## Run the pipeline to build the pipeline image
1. Clone the repo to your Gitlab account
1. Launch the following CloudFormation template to create the pipeline user, roles, and S3 bucket for terraform state.  Take default values. [![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=InfraPipeSetup&templateURL=https://shiftsecurityleft-infrapipe-cf.s3.amazonaws.com/infrapipe/branch/master/cf-templates/infrapipe-setup.cfn.yaml) 
1. Once the CF stack is completed, you can review resources that are created.
1. In AWS CloudFormation console, go to resources -> click on the user created -> IAM users/terraform -> security credentials, and create a Access key
1. Add the following variable to GitLab team's variable 
   - DEV_AWS_ACCESS_KEY = <access key>
   - DEV_AWS_SECRET_KEY = <secret key>
   - DEV_AWS_DEFAULT_REGION = <your AWS default region>
1. From the cloned repo dir, create a tf-DEV-setup branch
   git checkout -b tf-DEV-setup



## Above CloudFormation auto-generates the following AWS resources.
1. IAM role for pipeline: must trust above IAM user
1. Add IAM role name to SSM security/pipeline/<ENV>/AWS_ASSUME_ROLE_ARN
1. S3 bucket for terraform state remote backend
1. Add above S3 bucket name to SSM security/pipeline/<ENV>/AWS_TFSTATE_S3_BUCKET
1. Add above S3 key to SSM security/pipeline/<ENV>/AWS_TFSTATE_S3_KEY


## How to create a example app
1, npx create-react-app app
1. cd app
1. npm install



## Prerequsit

## Authors

Module managed by [ShiftSecurityLeft](https://shiftsecurityleft.io).

