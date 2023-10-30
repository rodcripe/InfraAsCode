terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-atividade4"
  location = "brazilsouth"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-atividade4"
  address_space       = ["10.0.0.0/16", "192.168.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-atividade4"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "ippublico" {
  name                    = "nic-atividade4"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
  domain_name_label       = "vmwin2k19"

}

resource "azurerm_network_interface" "nic" {
  name                = "nic-atividade4"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "ippublico-conf"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ippublico.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-atividade4"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

variable "regras_entrada" {
  type = map(any)
  default = {
    101 = 3389
    102 = 5986
    103 = 80
    104 = 443
  }
}

resource "azurerm_network_security_rule" "portas_liberadas" {
  for_each                    = var.regras_entrada
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "porta_entrada_${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  source_port_range           = "*"
  protocol                    = "Tcp"
  destination_port_range      = each.value
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface_security_group_association" "nsgassociation" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id

}

resource "azurerm_windows_virtual_machine" "vmwin2k19" {
  name                = "vmwin2k19"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  size           = "Standard_D2s_v3"
  admin_username = "adminuser"
  admin_password = var.PASSWORD

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  provision_vm_agent         = true
  allow_extension_operations = true

}

resource "azurerm_virtual_machine_extension" "vmext" {
  name                 = azurerm_windows_virtual_machine.vmwin2k19.name
  virtual_machine_id   = azurerm_windows_virtual_machine.vmwin2k19.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1",
        "fileUris": ["https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"]
    }
   SETTINGS

  depends_on = [
    azurerm_public_ip.ippublico
  ]
}
