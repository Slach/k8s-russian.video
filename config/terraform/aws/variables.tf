variable "k8stoken" {
  default = ""
  description = "Overrides the auto-generated bootstrap token"
}

resource "random_string" "k8stoken-first-part" {
  length = 6
  upper = false
  special = false
}

resource "random_string" "k8stoken-second-part" {
  length = 16
  upper = false
  special = false
}

locals {
  k8stoken = var.k8stoken == "" ? "${random_string.k8stoken-first-part.result}.${random_string.k8stoken-second-part.result}" : var.k8stoken
}

variable "cluster-name" {
  default = "k8s"
  description = "Controls the naming of the AWS resources"
}

variable "access_key" {
  default = ""
}

variable "secret_key" {
  default = ""
}

variable "k8s-ssh-key" {
  default = "kubeadm-aws"
}

variable "admin-cidr-blocks" {
  description = "A comma separated list of CIDR blocks to allow SSH connections from."
  default = "0.0.0.0/0"
}

variable "region" {
  default = "us-east-1"
}

variable "az" {
  default = "a"
}

variable "kubernetes-version" {
  default = "1.17.3"
  description = "Which version of Kubernetes to install"
}

variable "helm-version" {
  default = "3.1.0"
  description = "Which version of Helm to install"
}

variable "master-instance-type" {
  default = "t3.small"
  description = "Which EC2 instance type to use for the master nodes"
}

variable "master-spot-price" {
  default = "0.01"
  description = "The maximum spot bid for the master node"
}

variable "worker-instance-type" {
  default = "t3.small"
  description = "Which EC2 instance type to use for the worker nodes"
}

variable "worker-spot-price" {
  default = "0.01"
  description = "The maximum spot bid for worker nodes"
}

variable "min-worker-count" {
  default = "1"
  description = "The minimum worker node count"
}

variable "max-worker-count" {
  default = "1"
  description = "The maximum worker node count"
}

variable "backup-enabled" {
  default = "1"
  description = "Whether or not the automatic S3 backup should be enabled. (1 for enabled, 0 for disabled)"
}

variable "backup-cron-expression" {
  default = "*/15 * * * *"
  description = "A cron expression to use for the automatic etcd backups."
}

variable "external-dns-enabled" {
  default = "1"
  description = "Whether or not to enable external-dns. (1 for enabled, 0 for disabled)"
}

variable "nginx-ingress-enabled" {
  default = "1"
  description = "Whether or not to enable nginx ingress. (1 for enabled, 0 for disabled)"
}

variable "nginx-ingress-domain" {
  default = "aws.k8s-russian.video"
  description = "The DNS name to map to Nginx Ingress (using External DNS)"
}

variable "cert-manager-enabled" {
  default = "1"
  description = "Whether or not to enable the cert manager. (1 for enabled, 0 for disabled)"
}

variable "cert-manager-email" {
  default = "bloodjazman@gmail.com"
  description = "The email address to use for Let's Encrypt certificate requests"
}

variable "cluster-autoscaler-enabled" {
  default = "0"
  description = "Whether or not to enable the cluster autoscaler. (1 for enabled, 0 for disabled)"
}
