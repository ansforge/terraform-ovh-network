terraform {
  required_providers {
    ovh       = { source = "ovh/ovh" }
    openstack = { source = "terraform-provider-openstack/openstack" }
  }
}

resource "ovh_cloud_project_network_private" "vlan" {
  for_each     = var.vlans
  service_name = var.service_name
  name         = each.value.name
  vlan_id      = each.value.vlan_id
  regions      = [var.region]
}

resource "openstack_networking_subnet_v2" "subnet" {
  for_each   = var.vlans
  region     = var.region
  network_id = tolist(ovh_cloud_project_network_private.vlan[each.key].regions_attributes)[0].openstackid
  cidr       = each.value.cidr
  name       = each.value.name

  gateway_ip = each.value.gateway_ip != null ? each.value.gateway_ip : null
  no_gateway = each.value.gateway_ip == null ? true : null

  enable_dhcp = each.value.enable_dhcp
  dns_nameservers = each.value.enable_dhcp ? ["213.186.33.99", "8.8.8.8"] : []

  allocation_pool {
    start = each.value.start
    end   = each.value.end
  }
}
