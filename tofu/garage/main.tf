terraform {
  required_providers {
    garage = {
      source  = "registry.terraform.io/henrywhitaker3/garage"
      version = "~> 1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "garage" {
  host   = "127.0.0.1:3903"
  scheme = "http"
  token  = var.garage_admin_token
}

# AWS provider pointed at the local garage S3 API. Used for S3-standard
# operations the henrywhitaker3/garage provider does not expose -- notably
# PutBucketWebsite, which is how garage flags a bucket as anonymously
# serveable via the s3_web endpoint. Credentials come from a per-bucket
# writer key declared in garage.tf.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = garage_access_key.scottylabs_assets_writer.access_key_id
  secret_key                  = garage_access_key.scottylabs_assets_writer.secret_access_key
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    s3 = "http://127.0.0.1:3900"
  }
}
