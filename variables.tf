variable "service_name" {
  type        = string
  description = "ID du projet OVHcloud"
}

variable "region" {
  type        = string
  description = "Région OVHcloud/OpenStack"
}

variable "vlans" {
  description = "Map des VLANs à créer avec leurs subnets"
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

# --- Credentials ---
variable "ovh_application_key" {
  type = string
}

variable "ovh_application_secret" {
  type = string
}

variable "ovh_consumer_key" {
  type = string
}

variable "os_auth_url" {
  type = string
}

variable "os_user" {
  type = string
}

variable "os_password" {
  type = string
}
