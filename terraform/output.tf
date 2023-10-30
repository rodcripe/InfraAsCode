output "public_ip_address_id" {
  value = azurerm_public_ip.ippublico.*.ip_address
  depends_on = [
    azurerm_windows_virtual_machine.vmwin2k19
  ]
}