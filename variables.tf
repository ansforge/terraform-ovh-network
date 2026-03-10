variable "service_name" { type = string }
variable "region" { type = string }

variable "ovh_application_key" { type = string }
variable "ovh_application_secret" { type = string }
variable "ovh_consumer_key" { type = string }

variable "vlans" {
  type = map(object({
    vlan_id    = number
    name       = string
    cidr       = string
    start      = string
    end        = string
    dhcp       = optional(bool, false)
    no_gateway = optional(bool, true)
  }))
}
