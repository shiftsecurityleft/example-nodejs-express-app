# Infrapipe - Example App (Nodejs/Express)

Infrapipe is an opinionated pipeline that is configured to work with a specific CI tool.  The intent is to make Engineers, Developers , and other enthusiasts quickly productive in deploying "known-good" application architectures into the most common cloud platform technologies.  The aspirational goal is to have the experience of going from "git clone" to production as fast as possible.

## About - Example App (Nodejs/Express)
-   Continuous Integration (CI) Platform = Gitlab
-   Application Runtime = Dockerized Express Web Server with a HelloWorld app
-   Cloud Hosting Platform = AWS
-   Container Hosting Platform = AWS Elastic Container Service (ECS) + Fargate SPOT
-   Ingress LoadBalancer = AWS Application Load Balancer (ALB)
-   Infrastructure as Code (IaC) Platform = Terraform

## Before you start make sure you have following
-   Gitlab account.
-   AWS Account with temporary Administrator Role access.
-   Workstation with Git verions 2.2X or greater installed
-   Workstation with a text/code editor (example: vscode https://code.visualstudio.com/)
## Quick Start Guide

## Setup your Gitlab Account and workstation for Infrapipe
1. Clone the repo to your Gitlab account
1. Launch the following CloudFormation template to create the pipeline user, roles, and S3 bucket for terraform state.  Take default values. [![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=InfraPipeSetup&templateURL=https://shiftsecurityleft-infrapipe-cf.s3.amazonaws.com/infrapipe/branch/master/cf-templates/infrapipe-setup.cfn.yaml) 
1. Once the CF stack is completed, you can review resources that are created.
1. In AWS CloudFormation console, go to resources -> click on the user created -> IAM users/terraform -> security credentials, and create a Access key
1. Add the following variable to GitLab team's variable 
   - DEV_AWS_ACCESS_KEY = <access key>
   - DEV_AWS_SECRET_KEY = <secret key>
   - DEV_AWS_DEFAULT_REGION = <your AWS default region>

## Deploy Infrastructure
1. From the cloned repo dir, create a tf-DEV-setup branch
   git checkout -b tf-DEV-setup
1. Push your new local branch to your gitlab account,
   git push
1. Set the remote branch as upstream when prompted,
   git push --set-upstream origin tf-DEV-setup
1. Be ready to provide your gitlab userid and personal access token when prompted.
1. When pushed successfully, check your gitlab account to see if your new branch has been pushed and if the pipeline "plan" step has started.
1. Only after a successful pipeline "Plan" run, Click on the "Apply" step to execute the infrastructure build. If the "Apply" step ran successfully, it should be colored in green.
1. Your Infrapipe built AWS ECS + Fargate SPOT Infrastructure is ready for application deployments

## Deploy an Application
1. Checkout a new application release branch to initiate an application deployment, git checkout -b featureMyApp ; git push
1. Set the remote branch as upstream when prompted,
   git push --set-upstream origin featureMyApp
1. Check your gitlab account for the new branch and the execution of the pipeline.
1. Application deployments have different pipeline steps that you will see in your Gitlab account. Your application has been successfully deployed once it completes the deployment step. You can find your application deployment url at the end of the log of the pipeline run.


## Authors

Module managed by [ShiftSecurityLeft](https://shiftsecurityleft.io).

