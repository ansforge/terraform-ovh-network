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
  endpoint = "ovh-eu"
  # Le provider OVH utilise automatiquement les variables d'environnement :
  # OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY
}

provider "openstack" {
  # Les variables de credentials OpenStack sont passées via le tfvars
  # ou via des variables d'environnement spécifiques au provider (OS_...)
  auth_url                      = var.os_auth_url
  application_credential_id     = var.os_user
  application_credential_secret = var.os_password
  region                        = var.region
}

# --- Appel du Module Réseau ---
module "vlan_infra" {
  source = "./modules/network"

  service_name = var.service_name
  region       = var.region
  vlans        = var.vlans
}
