terraform {
  required_providers {
    ovh       = { source = "ovh/ovh" }
    openstack = { source = "terraform-provider-openstack/openstack" }
  }
}

# 1. Création du réseau L2 par OVH
resource "ovh_cloud_project_network_private" "vlan" {
  for_each     = var.vlans
  service_name = var.service_name
  name         = each.value.name
  vlan_id      = each.value.vlan_id
  regions      = [var.region]
}

# 2. Création du Subnet via OpenStack (UUID fourni par OVH)
resource "openstack_networking_subnet_v2" "subnet" {
  for_each   = var.vlans
  region     = var.region

  # UUID OpenStack à partir de l'OVH VLAN
  network_id = tolist(ovh_cloud_project_network_private.vlan[each.key].regions_attributes)[0].openstackid

  cidr       = each.value.cidr
  name       = each.value.name

  gateway_ip      = each.key == "fwfe_front" ? cidrhost(each.value.cidr, 1) : cidrhost(each.value.cidr, 254)
  enable_dhcp     = true
  dns_nameservers = ["213.186.33.99"]

  allocation_pool {
    start = each.value.start
    end   = each.value.end
  }
}
