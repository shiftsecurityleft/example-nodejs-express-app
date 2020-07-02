variable VPC_NAME {}

variable DB_NAME {
  description = "Database name.  If empty, one will be created."
  default     = ""
}

variable SSM_PATH {}

variable RDS_USERNAME {
  default = "rdsuser"
}

variable RDS_MAJOR_VERSION {
  default = "10.6"
}

variable RDS_MINOR_VERSION {
  default = "10.6"
}

variable RDS_FAMILY {
  default = "postgres10"
}

variable RDS_SIZE {
  default = "db.t2.medium"
}

variable RDS_STORAGE_GB {
  default = "20"
}

#variable PWS_IP_RANGE {}

variable BACKUP_RETENTION_PERIOD {
  default = 0
}

variable BACKUP_WINDOW {
  # in UTC
  default = "03:00-06:00"
}

variable MAINTENANCE_WINDOW {
  default = "Mon:00:00-Mon:03:00"
}

variable APPLY_NOW {
  default = "true"
}

variable "TAGS" {
  type = "map"
}

##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["${var.VPC_NAME}"]
  }
}

data "aws_subnet_ids" "db" {
  vpc_id = "${data.aws_vpc.default.id}"

  tags = {
    Tier = "db"
  }
}

locals {
  tag_name = "${var.DB_NAME == "" ? random_pet.common.id : var.DB_NAME}"
}

resource "random_string" "password" {
  length           = 64
  special          = true
  override_special = "-._~"
}

resource "random_pet" "common" {
  length    = 2
  separator = ""
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/${var.SSM_PATH}/DB_PASSWORD"
  type      = "SecureString"
  value     = "${module.db.this_db_instance_password}"
  overwrite = true
}

resource "aws_ssm_parameter" "db_host" {
  name      = "/${var.SSM_PATH}/DB_HOST"
  type      = "String"
  value     = "${module.db.this_db_instance_endpoint}"
  overwrite = true
}

resource "aws_ssm_parameter" "db_database" {
  name      = "/${var.SSM_PATH}/DB_DATABASE"
  type      = "String"
  value     = "${module.db.this_db_instance_name}"
  overwrite = true
}

resource "aws_ssm_parameter" "db_username" {
  name      = "/${var.SSM_PATH}/DB_USERNAME"
  type      = "String"
  value     = "${module.db.this_db_instance_username}"
  overwrite = true
}

#####
# DB
#####
module "db" {
  apply_immediately = "${var.APPLY_NOW}"

  source = "terraform-aws-modules/terraform-aws-rds"

  identifier = "${local.tag_name}"

  engine = "postgres"

  engine_version              = "${var.RDS_MINOR_VERSION}"
  instance_class              = "${var.RDS_SIZE}"
  allocated_storage           = "${var.RDS_STORAGE_GB}"
  storage_encrypted           = true
  allow_major_version_upgrade = true
  auto_minor_version_upgrade  = true

  publicly_accessible = false

  # set to true for PROD to enable failover between AZ
  multi_az = false

  # DB parameter group
  family = "${var.RDS_FAMILY}"

  # DB option group
  major_engine_version = "${var.RDS_MAJOR_VERSION}"

  name                   = "${local.tag_name}"
  username               = "${local.tag_name}"
  password               = "${random_string.password.result}"
  port                   = "5432"
  vpc_security_group_ids = ["${aws_security_group.allow_rds.id}"]
  maintenance_window     = "${var.MAINTENANCE_WINDOW}"

  # Set to 0 to disable backups to create DB faster
  backup_retention_period = "${var.BACKUP_RETENTION_PERIOD}"
  backup_window           = "${var.BACKUP_WINDOW}"

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automaticall
  monitoring_interval = "30"

  monitoring_role_name   = "${local.tag_name}-role-monitor"
  create_monitoring_role = true

  # DB subnet group
  subnet_ids = ["${data.aws_subnet_ids.db.ids}"]

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "${local.tag_name}"

  parameters = [
    {
      name  = "rds.force_ssl"
      value = 1

      # For this parameter, This must set to pending-reboot instead of default : immediate.  Or it will fail.
      apply_method = "pending-reboot"
    },
  ]

  tags = "${merge(
		var.TAGS,
		map(
      "Name", "${local.tag_name}-rds-postgres"
		)
	)}"
}
