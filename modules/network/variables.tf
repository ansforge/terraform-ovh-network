variable "service_name" {
  type        = string
  description = "ID du projet OVHcloud"
}

variable "region" {
  type        = string
  description = "Région OVHcloud"
}

variable "vlans" {
  description = "Map des VLANs à créer"
  type = map(object({
    vlan_id    = number
    name       = string
    cidr       = string
    start      = string
    end        = string
    region     = string
    dhcp       = optional(bool, true)
    no_gateway = optional(bool, false)
  }))
}
