output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address_ansible_control_node" {
  value = azurerm_linux_virtual_machine.ansible_control_node.public_ip_address
}

output "public_ip_address_web_server" {
  value = azurerm_linux_virtual_machine.web_server.public_ip_address
}