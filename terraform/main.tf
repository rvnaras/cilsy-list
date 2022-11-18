provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    # config_path = "~/.kube/config"
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
      command     = "aws"
    }
  }
}

locals {
  name   = "ex-${replace(basename(path.cwd), "_", "-")}"
  region = "us-east-1"

  network_acls = {
    default_inbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    default_outbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 32768
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound = [
      {
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 120
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 130
        rule_action = "allow"
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number     = 140
        rule_action     = "allow"
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        ipv6_cidr_block = "::/0"
      },
    ]
    public_outbound = [
      {
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 120
        rule_action = "allow"
        from_port   = 1433
        to_port     = 1433
        protocol    = "tcp"
        cidr_block  = "10.0.100.0/22"
      },
      {
        rule_number = 130
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "10.0.100.0/22"
      },
      {
        rule_number = 140
        rule_action = "allow"
        icmp_code   = -1
        icmp_type   = 8
        protocol    = "icmp"
        cidr_block  = "10.0.0.0/22"
      },
      {
        rule_number     = 150
        rule_action     = "allow"
        from_port       = 90
        to_port         = 90
        protocol        = "tcp"
        ipv6_cidr_block = "::/0"
      },
    ]
  }
}

module "vpc" {
  source = "./modules/aws-vpc"

  name = var.vpc-name
  cidr = "10.0.0.0/16"

  azs               =  ["us-east-1a", "us-east-1b"]
  public_subnets    = ["10.0.1.0/24", "10.0.4.0/24"]
  private_subnets   = ["10.0.2.0/24", "10.0.5.0/24"]
  database_subnets  = ["10.0.3.0/24", "10.0.6.0/24"]

  public_subnet_names   = ["public-subnet-1", "public-subnet-2"]
  private_subnet_names  = ["private-subnet-1", "private-subnet-2"]
  database_subnet_names = ["db-subnet-1", "db-subnet-2"]

  public_dedicated_network_acl   = true
  public_inbound_acl_rules       = concat(local.network_acls["default_inbound"], local.network_acls["public_inbound"])
  public_outbound_acl_rules      = concat(local.network_acls["default_outbound"], local.network_acls["public_outbound"])
  
  database_subnet_group_name   = var.database_subnet_group_name
  create_database_subnet_group = true

  create_igw = var.create-igw
 
  enable_dns_hostnames = var.dns-hostname
  enable_dns_support   = var.dns-support

  enable_nat_gateway = var.enable-nat
  enable_vpn_gateway = var.enable-vpn
}

module "eks" {
  source = "./modules/aws-eks"

  cluster_name                    = var.eks-name
  cluster_version                 = var.eks-ver
  cluster_endpoint_private_access = var.eks-prv-endpoint
  cluster_endpoint_public_access  = var.eks-pub-endpoint

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_security_group_additional_rules = {
      ingress_nodes_TCP = {
      description                = "Node groups to Open TCP"
      protocol                   = "tcp"
      from_port                  = 0
      to_port                    = 65535
      type                       = "ingress"
      cidr_blocks                = ["0.0.0.0/0"]
    }
      egress_nodes = {
      description                = "Node groups to Open Connection"
      protocol                   = "-1"
      from_port                  = 0
      to_port                    = 0
      type                       = "egress"
      cidr_blocks                = ["0.0.0.0/0"]
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description      = "Node to node all TCP"
      protocol         = "tcp"
      from_port        = 0
      to_port          = 65535
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_group_defaults = {
    disk_size      = var.eks-node-disk-capacity
    instance_types = ["var.eks-node-instance-type"]
  }

  eks_managed_node_groups = {
    nodes = {
      name            = var.eks-nodeg-name
      use_name_prefix = false
      subnet_ids = module.vpc.public_subnets

      min_size     = 1
      max_size     = 3
      desired_size = 1

      capacity_type        = var.eks-node-ctype
      force_update_version = false
      instance_types       = var.eks-node-instance-type

      update_config = {
        # max_unavailable_percentage = 50
        max_unavailable = 1 
      }

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = false

      # block_device_mappings = {
      #   xvda = {
      #     device_name = "/dev/xvda"
      #     ebs = {
      #       volume_size           = var.eks-node-disk-capacity
      #       volume_type           = var.eks-node-disk-type
      #       encrypted             = true
      #       delete_on_termination = true
      #     }
      #   }
      # }

      create_iam_role          = true
      iam_role_name            = "eks-managed-node-group-iam"
      iam_role_use_name_prefix = false

      create_security_group          = false
      security_group_name            = "eks-managed-node-group-sg"
      security_group_use_name_prefix = false
    }
  }
}

module "rds" {
  source = "./modules/aws-rds"

  identifier = var.db-name

  engine               = var.db-engine
  engine_version       = "8.0.27"
  family               = "mysql8.0" 
  major_engine_version = "8.0"      
  instance_class       = var.db-instance-type

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "user"
  username = "root"
  password = "password"
  port     = 3306
  publicly_accessible = true

  multi_az               = false
  subnet_ids             = module.vpc.database_subnets
  db_subnet_group_name = module.vpc.database_subnet_group_name

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = false
  performance_insights_retention_period = 0
  create_monitoring_role                = false
  monitoring_interval                   = 0

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]
}

resource "helm_release" "cilist" {
  name       = "cilist"
  chart      = "cilist-web"
  # repository = "https://rvnaras.github.io/cilist-helm/"
  repository  = "./charts"
  namespace  = "staging"
  verify = false
  create_namespace = true
}
