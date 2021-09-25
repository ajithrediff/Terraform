# Create a resource group
resource "azurerm_resource_group" "my_rg" {
  name     = "my-resources-RG"
  location = "eastus"
 
  tags = {
    Owner = "APJ"
  }

}

# Network Configuation
resource "azurerm_virtual_network" "my_rg" {
  name                = "my-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.my_rg.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "my_rg" {
  count = var.my_vm_count
  name                = "my-nic-${count.index}"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name

  ip_configuration {
    name                          = "testconfiguration1-${count.index}"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = element(azurerm_public_ip.my-publicip.*.id, count.index)
  }
}

# Public IP config

resource "azurerm_public_ip" "my-publicip" {
  count               = var.my_vm_count
  name = "myPublicIP-${count.index}"
  location = "eastus"
  resource_group_name = azurerm_resource_group.my_rg.name
  allocation_method = "Dynamic"
}

#Security group

resource "azurerm_network_security_group" "mynsg" {
  name = "myNetworkSecurityGroup"
  location = "eastus"
  resource_group_name = azurerm_resource_group.my_rg.name
  
  security_rule {
    name = "SSH"
    priority = 1001
    direction = "Inbound"
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform Demo"
  }

}


resource "azurerm_virtual_machine" "my_rg" {
  count                 = var.my_vm_count
  name                  = "my-vm-${count.index}"
  location              = azurerm_resource_group.my_rg.location
  resource_group_name   = azurerm_resource_group.my_rg.name
  network_interface_ids = [element(azurerm_network_interface.my_rg.*.id,count.index)]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  lifecycle { 
    create_before_destroy = true
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "staging"
  }
}

data "azurerm_resources" "vmname" {
  resource_group_name = "my-resources-RG"
  type = "Microsoft.Compute/virtualMachines"
}

output "pip" {
  value = azurerm_public_ip.my-publicip
}

output "my_vm_public_ip" {
  value = azurerm_public_ip.my-publicip.*.ip_address
}

output "resource_name" {
  value = data.azurerm_resources.vmname.resources.*.name
}
