# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.92.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

variable "application" {
  type    = string
  default = "frontend"
}

variable "location" {
  type    = string
  default = "eastus"
}

locals {
  resource_group_name = "rg-${var.application}-${var.location}"
  storage_name = "stg${var.application}${var.location}"
  storage_share_name = "stg-shr-${var.application}${var.location}"
  service_plan_name = "sp-${var.application}-${var.location}"
  function_app_name = "fa-${var.application}-${var.location}"
  application_insights_name = "ai-${var.application}-${var.location}"
}

resource "azurerm_resource_group" "rg_workshop" {
  name     = local.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "stg_workshop" {
  name     = local.storage_name
  location = var.location

  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"

  resource_group_name = azurerm_resource_group.rg_workshop.name

  static_website {
    index_document = "index.html"
  }
}

resource "azurerm_storage_share" "stg_shr_workshop" {
  name  = local.storage_share_name
  quota = 2

  storage_account_name = azurerm_storage_account.stg_workshop.name
}

resource "azurerm_service_plan" "sp_workshop" {
  name     = local.service_plan_name
  location = var.location

  os_type  = "Windows"
  sku_name = "Y1"

  resource_group_name = azurerm_resource_group.rg_workshop.name
}

resource "azurerm_application_insights" "ai_workshop" {
  name             = local.application_insights_name
  application_type = "web"
  location         = var.location

  resource_group_name = azurerm_resource_group.rg_workshop.name
}

resource "azurerm_windows_function_app" "fa_workshop" {
  name     = local.function_app_name
  location = var.location

  service_plan_id     = azurerm_service_plan.sp_workshop.id
  resource_group_name = azurerm_resource_group.rg_workshop.name

  storage_account_name       = azurerm_storage_account.stg_workshop.name
  storage_account_access_key = azurerm_storage_account.stg_workshop.primary_access_key

  functions_extension_version = "~4"
  builtin_logging_enabled     = false

  site_config {
    always_on = false

    application_insights_key               = azurerm_application_insights.ai_workshop.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.ai_workshop.connection_string

    # For production systems set this to false, but consumption plan supports only 32bit workers
    use_32_bit_worker = true

    # Enable function invocations from Azure Portal.
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }

    application_stack {
      node_version = "~16"
    }
  }

  app_settings = {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.stg_workshop.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.stg_shr_workshop.name
  }

  # The app settings changes cause downtime on the Function App. e.g. with Azure Function App Slots
  # Therefore it is better to ignore those changes and manage app settings separately off the Terraform.
  lifecycle {
    ignore_changes = [
      app_settings,
      site_config["application_stack"], // workaround for a bug when azure just "kills" your app
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"]
    ]
  }
}