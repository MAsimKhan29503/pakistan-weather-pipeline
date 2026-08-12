resource "azurerm_data_factory" "main" {
  name                = "internshipadf01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }
}