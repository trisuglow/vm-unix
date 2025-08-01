resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
}

output "key_data_public" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "key_data_private" {
  value = azapi_resource_action.ssh_public_key_gen.output.privateKey
}

resource "local_file" "private_key" {
  content              = azapi_resource_action.ssh_public_key_gen.output.privateKey
  filename             = "./.ssh/id_rsa"
  file_permission      = "0600"
  directory_permission = "0600"
}

resource "local_file" "public_key" {
  content              = azapi_resource_action.ssh_public_key_gen.output.publicKey
  filename             = "./.ssh/id_rsa.pub"
  file_permission      = "0600"
  directory_permission = "0600"
}