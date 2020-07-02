# Use this terraform to create an ECS to run your application in a container
## Prerequsit:
1. VPC
2. RDS if required
3. Env vars in SSM Parameter Stores

## How-to
4. Branch with tf-${ENV}-xxx where ENV is the alias of AWS account where ECS should be created.
5. Execute empty-commit
