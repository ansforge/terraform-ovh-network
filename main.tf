terraform {
  required_providers {
    ovh       = { source = "ovh/ovh", version = ">= 2.11.0" }
    openstack = { source = "terraform-provider-openstack/openstack", version = ">= 1.53.0" }
    vault     = { source = "hashicorp/vault", version = ">= 3.25.0" }
  }
}

provider "vault" {
  skip_child_token = true
}

ephemeral "vault_kv_secret_v2" "ovh" {
  mount = "iacrunner-prod"
  name  = "ovh_key"
}

ephemeral "vault_kv_secret_v2" "os" {
  mount = "iacrunner-prod"
  name  = "openstack_key"
}

locals {
  ovh_creds = ephemeral.vault_kv_secret_v2.ovh.data
  os_creds  = ephemeral.vault_kv_secret_v2.os.data
}

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = local.ovh_creds["OVH_APPLICATION_KEY"]
  application_secret = local.ovh_creds["OVH_APPLICATION_SECRET"]
  consumer_key       = local.ovh_creds["OVH_CONSUMER_KEY"]
}

provider "openstack" {
  auth_url                      = local.os_creds["OS_AUTH_URL"]
  application_credential_id     = local.os_creds["OS_APPLICATION_CREDENTIAL_ID"]
  application_credential_secret = local.os_creds["OS_APPLICATION_CREDENTIAL_SECRET"]
  region                        = var.region
}

module "network" {
  source       = "./modules/network"
  service_name = var.service_name
  region       = var.region
  vlans        = var.vlans
}

# Gateway Internet rattachée au front (VLAN 100)
resource "ovh_cloud_project_gateway" "internet" {
  service_name = var.service_name
  name         = "Internet"
  region       = var.region
  model        = "s"

  # Utiliser l'UUID OpenStack pour le subnet
  network_id = module.network.network_uuids["fwfe_front"]
  subnet_id  = module.network.subnet_ids["fwfe_front"]
}
