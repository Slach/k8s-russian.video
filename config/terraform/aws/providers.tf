provider "aws" {
  version = "~> 2.7"
  # see ~/.aws/credentials
  #  access_key = var.access_key
  #  secret_key = var.secret_key
  region = var.region
}

provider "template" {
  version = "~> 2.1"
}

provider "random" {
  version = "~> 2.1"
}
