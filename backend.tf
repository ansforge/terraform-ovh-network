terraform {
  backend "s3" {
    bucket   = "infra-outils-sto-object-tf01"
    key      = "infra-outils-network.tfstate"
    region   = "eu-west-par"
    endpoints = {
      s3 = "https://s3.eu-west-par.io.cloud.ovh.net/"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
