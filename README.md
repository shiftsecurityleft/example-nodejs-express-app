# Infrapipe

Infrapipe is an opinionated delivery pipeline solution that is configured to work with a specific CI tool.  The intent is to make Engineers, Developers, and other enthusiasts quickly productive in deploying "known-good" application architectures into the most common cloud platform technologies.  

The aspirational goal is to have the experience of going from "git clone" to production as fast as possible.

Infrapipe combines the power of code and infrastructure being deployed from one repository and allowing developers to make strategic infrastructure changes along with their application code to enhance productivity.

### Example App (Node.js/Express)
This example includes:
- A sample "Hello world" Node.js/Express application
- Code to create an [AWS Elastic Container Service](https://aws.amazon.com/ecs/) cluster
-- Using [AWS Fargate](https://aws.amazon.com/fargate/) running on [AWS Spot](https://aws.amazon.com/ec2/spot/) instances

#### About
-   Continuous Integration (CI) Platform = [Gitlab](https://www.gitlab.com) 
-   Application Runtime = Dockerized Express Web Server with a HelloWorld app
-   Cloud Hosting Platform = [AWS](https://aws.amazon.com/)
-   Container Hosting Platform = AWS Elastic Container Service (ECS) + Fargate SPOT 
-   Ingress LoadBalancer = AWS Application Load Balancer (ALB)
-   Infrastructure as Code (IaC) Platform = [Terraform](https://www.terraform.io/)

### Dependencies
Before you start please have the following:
-   Gitlab account
-   AWS account with ability to creates IAM access/secret keys
-- Note: Example will create a new VPC
-   Workstation with [Git](https://git-scm.com/downloads) version 2.2X or greater installed
-   Workstation with a text/code editor (example: vscode https://code.visualstudio.com/)

## What is being built ##
[![infrastructure-view.jpg](https://i.postimg.cc/V6wRwH9j/infrastructure-view.jpg)](https://postimg.cc/bG6bHgBJ)

## Quick Start Guide
### Setup your Gitlab Account and workstation for Infrapipe
1. Import the [Github](https://github.com/shiftsecurityleft/example-nodejs-express-app.git) repo into a new project in your Gitlab account
[![import-project.jpg](https://i.postimg.cc/Fs1RWkng/import-project.jpg)](https://postimg.cc/KRSx4jbR)
1. Launch the following CloudFormation template to create the pipeline user, roles, and S3 bucket for terraform state.
-- This will launch the AWS console
-- Note the region (e.g. us-east-1, us-west-1)
-- Take default values
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=InfraPipeSetup&templateURL=https://shiftsecurityleft-infrapipe-cf.s3.amazonaws.com/infrapipe/branch/master/cf-templates/infrapipe-setup.cfn.yaml) 
1. Once the Cloud Formation stack is completed, you can review resources that are created in the console.
1. In AWS CloudFormation console:
-- Go to the Resources tab 
-- Click on the user created which will open the IAM console for the "terraform" user
-- Click on the Security credentials tab
-- Click on Create Access key (***Note: Keep this information in a secure location and NEVER share it with anyone***)
1. Add the following variables into GitLab's project variables
-- Go back to your Gitlab project
--  Hover over Settings
-- Click on CI/CD
-- Expand the Variables section
-- Click on Add Variable
[![gitlab-variables.jpg](https://i.postimg.cc/y6r0C3b8/gitlab-variables.jpg)](https://postimg.cc/WtgdMzVB)
- Add the following 3 variables
   - DEV_AWS_ACCESS_KEY = ACCESS_KEY
   - DEV_AWS_SECRET_KEY = SECRET_KEY
      -  ***Note: AWS_SECRET_KEY should be masked***
   - DEV_AWS_DEFAULT_REGION = AWS_REGION
      -  ***Note: Region should be in all lower case (e.g. us-east-1, us-west-2)***
6. Create a Gitlab Personal Access Token
--  Click on profile upper right hand corner drop down
--  Under User Settings click on Access Tokens
--  Provide a name for token
--  Choose appropriate scope
--  Save token in secure location

## Deploy Infrastructure
1. Clone Gitlab repo to your local machine
-- Be ready to provide your Gitlab userid and personal access token (created from above) when prompted
```sh
git clone https://gitlab.com/<login>/example-nodejs-express-app.git
cd example-nodejs-express-app
```
4. Be ready to provide your Gitlab userid and personal access token (created from above) when prompted.
2. From the cloned repo dir, create a tf-DEV-setup branch
```sh
git checkout -b tf-DEV-setup
```
2. Push your new local branch to your Gitlab account,
 ```sh
git push
```
3. Set the remote branch as upstream when prompted,
```sh   
git push --set-upstream origin tf-DEV-setup
```
4. When pushed successfully, check your Gitlab account to see if your new branch has been pushed and if the pipeline "plan_terraform" step has started.
--  Go to Gitlab
--  Under the example project click on CI / CD
--  Click on Pipelines
--  Click on "plan_terraform" button to see the status output
1. Only after a successful pipeline "plan_terraform" run (green checkbox), ***Click on the "apply_terraform" step*** to execute the infrastructure build (play button).
-- This is a manual step purposely to allow you to review the plan before executing the apply
1. Upon successful apploy your Infrapipe built AWS ECS + Fargate SPOT Infrastructure is ready for application deployments

## Deploy an Application
1. Going back to your terminal where you checked out your Gitlab project
2. Checkout a new application release branch to initiate an application deployment
```sh
git checkout -b featureMyApp ; git push
```
2. Set the remote branch as upstream when prompted
```sh
git push --set-upstream origin featureMyApp
```
3. Check your Gitlab CI/CD for the new branch and the execution of the pipeline.
1. Application deployments have different pipeline steps, including code quality and Source Code Analysis (SCA) that you will see in your Gitlab account
1. Your application has been successfully deployed once it completes the deployment step
2. You can find your application deployment url at the end of the log of the pipeline run
-- ***Note: Add a trailing "/" to the end of the URL into the browser***
-- ***Note: Fargate instance is set to auto shutdown after 10m to save costs.  This is configurable in the ecs-app.tf file***

### Making Changes
1. If you wanted to make changes to infrastructure or the app you would make them in your IDE in your Gitlab repo
2. Upon committing the change and pushing it the pipeline will execute and deploy your change
```sh
git commit -am "<description of change>"
git push
```
## Authors

Module managed by [ShiftSecurityLeft](https://shiftsecurityleft.io).
