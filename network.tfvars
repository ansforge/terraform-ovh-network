service_name = "a5a3658023e146e78a22afd04601b813"
region       = "SBG5"

vlans = {
  "fwfe_front"   = { vlan_id = 0, name = "preprod-amont-fwfe-front-10.12.0.0-24", cidr = "10.12.0.0/24", start = "10.12.0.51", end = "10.12.0.100" }
  "vrack_vpn"    = { vlan_id = 210, name = "preprod-amont-vrack-vpn-10.12.10.0-24", cidr = "10.12.10.0/24", start = "10.12.10.51", end = "10.12.10.100" }
  "fwfe_admin"   = { vlan_id = 220, name = "preprod-amont-fwfe-admin-10.12.20.0-24", cidr = "10.12.20.0/24", start = "10.12.20.51", end = "10.12.20.100" }
  
  "dmz_exposed" = {
    vlan_id     = 230
    name        = "preprod-amont-dmz-exposed-10.12.30.0-24"
    cidr        = "10.12.30.0/24"
    start       = "10.12.30.51"
    end         = "10.12.30.100"
    enable_dhcp = true
    gateway_ip  = "10.12.30.254"
  }

  "fw_interco"   = { vlan_id = 240, name = "preprod-amont-fw-interco-172.16.31.16-28", cidr = "172.16.31.16/28", start = "172.16.31.17", end = "172.16.31.30" }
  "fwbe_admin"   = { vlan_id = 250, name = "preprod-amont-fwbe-admin-10.12.50.0-24", cidr = "10.12.50.0/24", start = "10.12.50.51", end = "10.12.50.100" }
  "infra_admin"  = { vlan_id = 251, name = "preprod-amont-infra-admin-10.12.51.0-24", cidr = "10.12.51.0/24", start = "10.12.51.51", end = "10.12.51.100" }

  "dmz_admin" = {
    vlan_id     = 252
    name        = "preprod-amont-dmz-admin-10.12.52.0-24"
    cidr        = "10.12.52.0/24"
    start       = "10.12.52.51"
    end         = "10.12.52.100"
    enable_dhcp = true
    gateway_ip  = "10.12.52.253"
  }

  "k8s_front"    = { vlan_id = 260, name = "preprod-amont-k8s-front-10.12.60.0-24", cidr = "10.12.60.0/24", start = "10.12.60.51", end = "10.12.60.100" }
  "k8s_back"     = { vlan_id = 261, name = "preprod-amont-k8s-back-10.12.61.0-24", cidr = "10.12.61.0/24", start = "10.12.61.51", end = "10.12.61.100" }

  "dmz_transit" = {
    vlan_id     = 270
    name        = "preprod-amont-dmz-transit-10.12.70.0-24"
    cidr        = "10.12.70.0/24"
    start       = "10.12.70.51"
    end         = "10.12.70.100"
    enable_dhcp = true
    gateway_ip  = "10.12.70.253"
  }

  "fwbe_occ"     = { vlan_id = 280, name = "preprod-amont-fwbe-occ-172.16.31.0-28", cidr = "172.16.31.0/28", start = "172.16.31.1", end = "172.16.31.14" }

  "infra_app" = {
    vlan_id     = 290
    name        = "preprod-amont-infra-app-10.12.90.0-24"
    cidr        = "10.12.90.0/24"
    start       = "10.12.90.51"
    end         = "10.12.90.100"
    enable_dhcp = true
    gateway_ip  = "10.12.90.253"
  }

  "app_front"    = { vlan_id = 400, name = "preprod-amont-app-front-10.14.0.0-24", cidr = "10.14.0.0/24", start = "10.14.0.51", end = "10.14.0.100" }
  "app_middle"   = { vlan_id = 401, name = "preprod-amont-app-middle-10.14.1.0-24", cidr = "10.14.1.0/24", start = "10.14.1.51", end = "10.14.1.100" }
  "app_back"     = { vlan_id = 402, name = "preprod-amont-app-back-10.14.2.0-24", cidr = "10.14.2.0/24", start = "10.14.2.51", end = "10.14.2.100" }
}
