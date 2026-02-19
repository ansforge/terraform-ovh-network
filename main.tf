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

provider "ovh" {
  endpoint = "ovh-eu"
}

provider "openstack" {
  auth_url                      = var.os_auth_url
  application_credential_id     = var.os_user
  application_credential_secret = var.os_password
  region                        = var.region
}

# --- Appel du Module Réseau ---
module "vlan_infra" {
  source = "git::https://github.com/ansforge/terraform-ovh-network.git//modules/network?ref=amont"

  service_name = var.service_name
  region       = var.region
  vlans        = var.vlans
}
