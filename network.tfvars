service_name = "51b48fc072e34415922eb448c8121677"
region       = "EU-WEST-PAR"

vlans = {
  # --- IaaS (Stormshield) Outils ---
  "vrack_vpn"       = { vlan_id = 510, name = "outils-vrack-vpn-10.15.10.0-24", cidr = "10.15.10.0/24", start = "10.15.10.51", end = "10.15.10.100" }
  "fwfe_admin"      = { vlan_id = 520, name = "outils-fwfe-admin-10.15.20.0-24", cidr = "10.15.20.0/24", start = "10.15.20.51", end = "10.15.20.100" }
  "fw_interco_iaas" = { vlan_id = 640, name = "outils-fw-interco-172.16.26.16-28", cidr = "172.16.26.16/28", start = "172.16.26.17", end = "172.16.26.26" }
  "bastion_in"      = { vlan_id = 692, name = "outils-bastion-in-10.16.92.0-24", cidr = "10.16.92.0/24", start = "10.16.92.51", end = "10.16.92.100" }

  "dmz_exposed" = {
    vlan_id     = 530
    name        = "outils-dmz-exposed-10.15.30.0-24"
    cidr        = "10.15.30.0/24"
    start       = "10.15.30.51"
    end         = "10.15.30.100"
    enable_dhcp = true
    gateway_ip  = "10.15.30.251"
  }

  # --- HPC (OPNSense) Outils ---
  "fwbe_admin"     = { vlan_id = 650, name = "outils-fwbe-admin-10.16.50.0-24", cidr = "10.16.50.0/24", start = "10.16.50.51", end = "10.16.50.100" }
  "infra_admin"    = { vlan_id = 651, name = "outils-infra-admin-10.16.51.0-24", cidr = "10.16.51.0/24", start = "10.16.51.51", end = "10.16.51.100" }
  "dmz_admin"      = { vlan_id = 652, name = "outils-dmz-admin-10.16.52.0-24", cidr = "10.16.52.0/24", start = "10.16.52.51", end = "10.16.52.100" }
  "k8s"            = { vlan_id = 661, name = "outils-k8s-10.16.61.0-24", cidr = "10.16.61.0/24", start = "10.16.61.51", end = "10.16.61.100" }
  "dmz_transit"    = { vlan_id = 670, name = "outils-dmz-transit-10.16.70.0-24", cidr = "10.16.70.0/24", start = "10.16.70.51", end = "10.16.70.100" }

  "infra_app" = {
    vlan_id     = 690
    name        = "outils-infra-app-10.16.90.0-24"
    cidr        = "10.16.90.0/24"
    start       = "10.16.90.51"
    end         = "10.16.90.100"
    gateway_ip  = "10.16.90.253"
    enable_dhcp = true
  }
}
