terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = ">= 2.11.0"
    }
  }
}

# 1. Création des réseaux privés (VLANs)
resource "ovh_cloud_project_network_private" "vlan" {
  for_each     = var.vlans
  service_name = var.service_name
  name         = each.value.name
  vlan_id      = each.value.vlan_id
  regions      = [each.value.region]
}

# 2. Création des sous-réseaux (Subnets)
resource "ovh_cloud_project_network_private_subnet" "subnet" {
  for_each     = var.vlans
  service_name = var.service_name
  network      = each.value.cidr
  start        = each.value.start
  end          = each.value.end
  dhcp         = each.value.dhcp
  no_gateway   = each.value.no_gateway
  region       = each.value.region
  network_id   = ovh_cloud_project_network_private.vlan[each.key].id
}

