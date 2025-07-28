resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "ansible_control_node_public_ip" {
  name                = "ansible_control_node_public_ip"
  sku                 = "Standard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "web_server_public_ip" {
  name                = "web_server_public_ip"
  sku                 = "Standard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interfaces
resource "azurerm_network_interface" "ansible_control_node_nic" {
  name                = "ansible_control_node_nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ansible_control_node_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ansible_control_node_public_ip.id
  }
}

resource "azurerm_network_interface" "web_server_nic" {
  name                = "web_server_nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "web_server_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_server_public_ip.id
  }
}

# Connect the security group to the network interfaces
resource "azurerm_network_interface_security_group_association" "ansible_control_node_nsg_association" {
  network_interface_id      = azurerm_network_interface.ansible_control_node_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

resource "azurerm_network_interface_security_group_association" "web_server_nsg_association" {
  network_interface_id      = azurerm_network_interface.web_server_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine from which to run Ansible
resource "azurerm_linux_virtual_machine" "ansible_control_node" {
  name                  = "TRIS_ANSIBLE_CONTROL_NODE"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.ansible_control_node_nic.id]
  size                  = "Standard_B2as_v2"

  os_disk {
    name                 = "ACN_Disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "tris-ansible-control-node"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }

  # Create folder on control node to hold Ansible playbooks.
  provisioner "remote-exec" {
    inline = [ "mkdir ansible" ]

    connection {
      host        = azurerm_linux_virtual_machine.ansible_control_node.public_ip_address
      type        = "ssh"
      user        = var.username
      private_key = azapi_resource_action.ssh_public_key_gen.output.privateKey
    }
  }
  
  # Copy playbooks to control node.
  provisioner "file" {
    source      = "ansible/"
    destination = "ansible"

    connection {
      host        = azurerm_linux_virtual_machine.ansible_control_node.public_ip_address
      type        = "ssh"
      user        = var.username
      private_key = azapi_resource_action.ssh_public_key_gen.output.privateKey
    }
  }
  
  # Copy web files to control node.
  provisioner "file" {
    source      = "html/tristan.html"
    destination = "tristan.html"

    connection {
      host        = azurerm_linux_virtual_machine.ansible_control_node.public_ip_address
      type        = "ssh"
      user        = var.username
      private_key = azapi_resource_action.ssh_public_key_gen.output.privateKey
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Well done Sir. You have created a file. This is the Ansible control node.' >> readme",
      "chmod 444 readme",
      "chmod 777 ansible/apache.yml",      
      "chmod 777 ansible/website.yml",
      "echo '${azapi_resource_action.ssh_public_key_gen.output.privateKey}' >> .ssh/web_id_rsa",
      "sudo chmod 600 .ssh/web_id_rsa",
      "sudo apt update",
      "sudo apt install software-properties-common",
      "sudo add-apt-repository --yes --update ppa:ansible/ansible",
      "sudo apt install ansible --yes",
      "ansible --version",
      "sudo chmod 777 /etc/ansible/ansible.cfg",
      "cp ansible/ansible.cfg /etc/ansible/ansible.cfg",
      "ansible-playbook -v -u ${var.username} -i ${azurerm_linux_virtual_machine.web_server.public_ip_address}, --private-key ./.ssh/web_id_rsa /home/${var.username}/ansible/smoketest.yml",
      # "ansible-playbook -v -u ${var.username} -i ${azurerm_linux_virtual_machine.web_server.public_ip_address}, --private-key ./.ssh/web_id_rsa /home/${var.username}/ansible/apache.yml",
      # "ansible-playbook -v -u ${var.username} -i ${azurerm_linux_virtual_machine.web_server.public_ip_address}, --private-key ./.ssh/web_id_rsa /home/${var.username}/ansible/website.yml"
    ]

    connection {
      host        = azurerm_linux_virtual_machine.ansible_control_node.public_ip_address
      type        = "ssh"
      user        = var.username
      private_key = azapi_resource_action.ssh_public_key_gen.output.privateKey
    }
  }
}

# Create virtual machine to host web page
resource "azurerm_linux_virtual_machine" "web_server" {
  name                  = "TRIS_WEB_SERVER"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.web_server_nic.id]
  size                  = "Standard_B2as_v2"

  os_disk {
    name                 = "WS_DISK"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "tris-web-server"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
"New-Item 'launch.ps1' -ItemType File -Force -Value 'Start-Process http://${azurerm_linux_virtual_machine.web_server.public_ip_address}/tristan.html'"
     EOT
    interpreter = ["PowerShell", "-Command"]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Well done Sir. You have created a file. This is the web host machine.' >> readme",
      "chmod 444 readme"
    ]

    connection {
      host        = azurerm_linux_virtual_machine.web_server.public_ip_address
      type        = "ssh"
      user        = var.username
      private_key = azapi_resource_action.ssh_public_key_gen.output.privateKey
    }
  }
}
