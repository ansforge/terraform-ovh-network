# --- terraform-ovh-network/variables.tf ---

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

# --- Credentials OpenStack (utilisés dans main.tf) ---
variable "os_auth_url" {
  type        = string
  description = "URL d'authentification OpenStack"
}

variable "os_user" {
  type        = string
  description = "Utilisateur OpenStack"
}

variable "os_password" {
  type        = string
  description = "Mot de passe OpenStack"
}
