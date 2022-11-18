variable "vpc-name" {
    description = "VPC?"
    type        = string
    default     = "cilist-vpc"
}

variable "eks-name" {
    description = "EKS Name?"
    type        = string
    default     = "cilist-cluster"
}

variable "eks-ver" {
    description = "EKS Version?"
    type        = string
    default     = "1.22"
}

variable "dns-hostname" {
    description = "DNS Hostname"
    type        = bool
    default     = true
}

variable "dns-support" {
    description = "DNS Support"
    type        = bool
    default     = true
}

variable "create-igw" {
    description = "Create Internet Gateway?"
    type        = bool
    default     = true
}

variable "enable-nat" {
    description = "Create NAT?, EIP will automatically created"
    type        = bool
    default     = false
}

variable "enable-vpn" {
    description = "Create VPN?"
    type        = bool
    default     = false
}

variable "database_subnet_group_name" {
    description = "DB Subnet Group Name?"
    type        = string
    default     = "cilist-db-subnet-group"
}

variable "eks-prv-endpoint" {
    description = "EKS Private Endpoint?"
    type        = bool
    default     = true
}

variable "eks-pub-endpoint" {
    description = "EKS Public Endpoint?"
    type        = bool
    default     = true
}

variable "eks-nodeg-name" {
    description = "EKS Node Group Name?"
    type        = string
    default     = "cluster-nodegroup"
}

variable "eks-node-ctype" {
    description = "EKS Capacity Type?, SPOT or ON_DEMAND"
    type        = string
    default     = "ON_DEMAND"
}

variable "eks-node-instance-type" {
    description = "EKS Instance Type?"
    type        = list(string)
    default     = ["t3.medium"]
}

variable "eks-node-disk-capacity" {
    description = "EKS Node Disk Capacity?"
    type        = string
    default     = "20"
}

variable "eks-node-disk-type" {
    description = "EKS Node Disk Type?"
    type        = string
    default     = "gp2"
}

variable "db-name" {
    description = "RDS Name?"
    type        = string
    default     = "cilist-database"
}

variable "db-engine" {
    description = "RDS Engine?"
    type        = string
    default     = "mysql"
}

variable "db-instance-type" {
    description = "RDS Instance Type?"
    type        = string
    default     = "db.t3.micro"
}

variable "db-disk-size-allocate" {
    description = "DB Disk Allocate?"
    type        = string
    default     = "20"
}

variable "db-disk-size-max" {
    description = "DB Disk Max Allocate?"
    type        = string
    default     = 100
}