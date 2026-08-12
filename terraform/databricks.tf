resource "azurerm_databricks_workspace" "main" {
  name                = "internship_databricks_ws"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "premium"

  managed_resource_group_name = "databricks-rg-internship_databricks_ws-ph7tnmtbdd5yq"

  lifecycle {
    ignore_changes = [
      public_network_access_enabled
    ]
  }
}