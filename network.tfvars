# --- OpenStack Auth ---
os_auth_url = "https://auth.cloud.ovh.net/v3/"
os_user     = "5322855a312548738bfcc487c3a17cdd"
os_password = "quOw_e1ov11pyQrNbV_w-zAcA42zOq854kQac0I5Ct1DcvPhkeTh2aazqh8GJh8YHRzVeySXSMyb7IuImBaOXw"

# --- Projet et Région ---
service_name = "a5a3658023e146e78a22afd04601b813"
region       = "SBG5"

# --- VLANs (Configuration réseau) ---
vlans = {
  admin = {
    vlan_id    = 1011
    name       = "fwfe-amont-admin-172.16.11.0-24"
    cidr       = "172.16.11.0/24"
    start      = "172.16.11.10"
    end        = "172.16.11.254"
    region     = "SBG5"
    dhcp       = false
    no_gateway = false
  }

interco_fw = {
    vlan_id    = 1021
    # CORRECTION ICI : Nom aligné sur l'API OVH (tiret au lieu de slash)
    name       = "fw-amont-interco-172.16.21.0-24" 
    cidr       = "172.16.21.0/24"
    start      = "172.16.21.10"
    end        = "172.16.21.254"
    region     = "SBG5"
    dhcp       = false
    no_gateway = true
    }

  ip_front = {
    vlan_id    = 1031
    name       = "fwfe-amont-front-172.16.31.0-24"
    cidr       = "172.16.31.0/24"
    start      = "172.16.31.10"
    end        = "172.16.31.254"
    region     = "SBG5"
    dhcp       = false
    no_gateway = true
  }

  vlan_tech = {
    vlan_id    = 1041
    name       = "fwfe-amont-tech-172.16.41.0-24"
    cidr       = "172.16.41.0/24"
    start      = "172.16.41.10"
    end        = "172.16.41.254"
    region     = "SBG5"
    dhcp       = false
    no_gateway = false
  }

  amont_outillage = {
    vlan_id = 150
    name    = "amont-outillage-lan"
    cidr    = "10.25.50.0/24"
    start   = "10.25.50.100"
    end     = "10.25.50.200"
    region  = "SBG5"
  }
}
