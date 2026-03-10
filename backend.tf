terraform {
  backend "s3" {
    bucket   = "infra-prod-sto-object-tf01"
    key      = "infra-production-network.tfstate"
    region   = "rbx"
    endpoints = { 
      s3 = "https://s3.rbx.io.cloud.ovh.net/" 
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
