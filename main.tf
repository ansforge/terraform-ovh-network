# --- terraform-ovh-network/main.tf ---

terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = ">= 2.11.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 3.4.0"
    }
  }
}

# Providers
provider "ovh" {
  endpoint            = "ovh-eu"
  application_key     = var.ovh_application_key
  application_secret  = var.ovh_application_secret
  consumer_key        = var.ovh_consumer_key
}

provider "openstack" {
  auth_url                        = var.os_auth_url
  application_credential_id       = var.os_user
  application_credential_secret   = var.os_password
  region                          = var.region
}

# --- MODIFICATION ICI : La source pointe vers le dossier local ---
module "vlan_infra" {
  source = "./modules/network"

  service_name = var.service_name
  region       = var.region
  vlans        = var.vlans
}
