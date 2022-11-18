data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_default_tags" "current" {}

locals {
  create = var.create 

  cluster_role = try(aws_iam_role.this[0].arn, var.iam_role_arn)
}

################################################################################
# Cluster
################################################################################

resource "aws_eks_cluster" "this" {
  count = local.create ? 1 : 0

  name                      = var.cluster_name
  role_arn                  = local.cluster_role
  version                   = var.cluster_version
  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    security_group_ids      = compact(distinct(concat(var.cluster_additional_security_group_ids, [local.cluster_security_group_id])))
    subnet_ids              = coalescelist(var.control_plane_subnet_ids, var.subnet_ids)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  kubernetes_network_config {
    ip_family         = var.cluster_ip_family
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
  }

  tags = merge(
    var.tags,
    var.cluster_tags,
  )

  timeouts {
    create = lookup(var.cluster_timeouts, "create", null)
    update = lookup(var.cluster_timeouts, "update", null)
    delete = lookup(var.cluster_timeouts, "delete", null)
  }

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_security_group_rule.cluster,
    aws_security_group_rule.node,
    # aws_cloudwatch_log_group.this
  ]
}

resource "aws_ec2_tag" "cluster_primary_security_group" {
  # This should not affect the name of the cluster primary security group
  # Ref: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2006
  # Ref: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2008
  # `aws_default_tags` is merged in to "dedupe" tags and stabilize tag updates
  for_each = { for k, v in merge(var.tags, var.cluster_tags, data.aws_default_tags.current.tags) :
    k => v if local.create && k != "Name" && var.create_cluster_primary_security_group_tags
  }

  resource_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
  key         = each.key
  value       = each.value
}

# resource "aws_cloudwatch_log_group" "this" {
#   count = local.create && var.create_cloudwatch_log_group ? 1 : 0

#   name              = "/aws/eks/${var.cluster_name}/cluster"
#   retention_in_days = var.cloudwatch_log_group_retention_in_days
#   kms_key_id        = var.cloudwatch_log_group_kms_key_id

#   tags = var.tags
# }

################################################################################
# Cluster Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
################################################################################

locals {
  cluster_sg_name   = coalesce(var.cluster_security_group_name, "${var.cluster_name}-cluster")
  create_cluster_sg = local.create && var.create_cluster_security_group

  cluster_security_group_id = local.create_cluster_sg ? aws_security_group.cluster[0].id : var.cluster_security_group_id

  # Do not add rules to node security group if the module is not creating it
  cluster_security_group_rules = local.create_node_sg ? {
    ingress_nodes = {
      description                = "Node groups to cluster API"
      protocol                   = "-1"
      from_port                  = 0
      to_port                    = 0
      type                       = "ingress"
      source_node_security_group = true
    }
    egress_nodes = {
      description                = "Cluster API to node groups"
      protocol                   = "-1"
      from_port                  = 0
      to_port                    = 0
      type                       = "egress"
      source_node_security_group = true
    }
    # egress_nodes_kubelet = {
    #   description                = "Cluster API to node kubelets"
    #   protocol                   = "tcp"
    #   from_port                  = 10250
    #   to_port                    = 65535
    #   type                       = "egress"
    #   source_node_security_group = true
    # }
  } : {}
}

resource "aws_security_group" "cluster" {
  count = local.create_cluster_sg ? 1 : 0

  name        = var.cluster_security_group_use_name_prefix ? null : local.cluster_sg_name
  name_prefix = var.cluster_security_group_use_name_prefix ? "${local.cluster_sg_name}${var.prefix_separator}" : null
  description = var.cluster_security_group_description
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { "Name" = local.cluster_sg_name },
    var.cluster_security_group_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster" {
  for_each = { for k, v in merge(local.cluster_security_group_rules, var.cluster_security_group_additional_rules) : k => v if local.create_cluster_sg }

  # Required
  security_group_id = aws_security_group.cluster[0].id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  # Optional
  description      = try(each.value.description, null)
  cidr_blocks      = try(each.value.cidr_blocks, null)
  ipv6_cidr_blocks = try(each.value.ipv6_cidr_blocks, null)
  prefix_list_ids  = try(each.value.prefix_list_ids, [])
  self             = try(each.value.self, null)
  source_security_group_id = try(
    each.value.source_security_group_id,
    try(each.value.source_node_security_group, false) ? local.node_security_group_id : null
  )
}

################################################################################
# IAM Role
################################################################################

locals {
  create_iam_role   = local.create && var.create_iam_role
  iam_role_name     = coalesce(var.iam_role_name, "${var.cluster_name}-cluster")
  policy_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"

  cluster_encryption_policy_name = coalesce(var.cluster_encryption_policy_name, "${local.iam_role_name}-ClusterEncryption")

  # TODO - hopefully this can be removed once the AWS endpoint is named properly in China
  # https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1904
  dns_suffix = coalesce(var.cluster_iam_role_dns_suffix, data.aws_partition.current.dns_suffix)
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = local.create && var.create_iam_role ? 1 : 0

  statement {
    sid     = "EKSClusterAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.${local.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = local.create_iam_role ? 1 : 0

  name        = var.iam_role_use_name_prefix ? null : local.iam_role_name
  name_prefix = var.iam_role_use_name_prefix ? "${local.iam_role_name}${var.prefix_separator}" : null
  path        = var.iam_role_path
  description = var.iam_role_description

  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy[0].json
  permissions_boundary  = var.iam_role_permissions_boundary
  force_detach_policies = true

  # https://github.com/terraform-aws-modules/terraform-aws-eks/issues/920
  # Resources running on the cluster are still generaring logs when destroying the module resources
  # which results in the log group being re-created even after Terraform destroys it. Removing the
  # ability for the cluster role to create the log group prevents this log group from being re-created
  # outside of Terraform due to services still generating logs during destroy process
  dynamic "inline_policy" {
    for_each = var.create_cloudwatch_log_group ? [1] : []
    content {
      name = local.iam_role_name

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = ["logs:CreateLogGroup"]
            Effect   = "Deny"
            Resource = "*"
          },
        ]
      })
    }
  }

  tags = merge(var.tags, var.iam_role_tags)
}

# Policies attached ref https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.create_iam_role ? toset(compact(distinct(concat([
    "${local.policy_arn_prefix}/AmazonEKSClusterPolicy",
    "${local.policy_arn_prefix}/AmazonEKSVPCResourceController",
  ], var.iam_role_additional_policies)))) : toset([])

  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

################################################################################
# EKS Addons
################################################################################

resource "aws_eks_addon" "this" {
  for_each = { for k, v in var.cluster_addons : k => v if local.create }

  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = try(each.value.name, each.key)

  addon_version            = lookup(each.value, "addon_version", null)
  resolve_conflicts        = lookup(each.value, "resolve_conflicts", null)
  service_account_role_arn = lookup(each.value, "service_account_role_arn", null)

  depends_on = [
    module.eks_managed_node_group,
  ]

  tags = var.tags
}
