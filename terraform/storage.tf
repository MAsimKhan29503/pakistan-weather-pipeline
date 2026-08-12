resource "azurerm_storage_account" "main" {
  name                = "internshipdlsa01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  access_tier     = "Hot"
  is_hns_enabled  = true
  min_tls_version = "TLS1_2"


  allow_nested_items_to_be_public = false
}