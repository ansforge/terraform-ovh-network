output "subnet_ids" {
  value = { for k, v in ovh_cloud_project_network_private_subnet.subnet : k => v.id }
}
