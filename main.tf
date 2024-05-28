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
  api_management = "apim-${var.application}-${var.location}"
  api_management_api = "products-service-api"
  api_management_backend = "products-service-backend"
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

resource "azurerm_api_management" "apim_workshop" {
  name                = local.api_management
  location            = azurerm_resource_group.rg_workshop.location
  resource_group_name = azurerm_resource_group.rg_workshop.name

  publisher_name      = "Artyom Gospodarsky"
  publisher_email     = "azure@gospodarsky.simplelogin.com"

  sku_name = "Consumption_0"
}

resource "azurerm_api_management_api" "apim_api_workshop" {
  name                = local.api_management_api
  resource_group_name = azurerm_resource_group.rg_workshop.name
  api_management_name = azurerm_api_management.apim_workshop.name
  revision            = "1"
  display_name = "Products Service API"
  protocols = ["https"]
  subscription_required = false
}

data "azurerm_function_app_host_keys" "products_keys" {
  name = azurerm_windows_function_app.fa_workshop.name
  resource_group_name = azurerm_resource_group.rg_workshop.name
}

resource "azurerm_api_management_backend" "apim_backend_workshop" {
  name = local.api_management_backend
  resource_group_name = azurerm_resource_group.rg_workshop.name
  api_management_name = azurerm_api_management.apim_workshop.name
  protocol = "http"
  url = "https://${azurerm_windows_function_app.fa_workshop.name}.azurewebsites.net/api"
  description = "Products API"

  credentials {
    certificate = []
    query = {}

    header = {
      "x-functions-key" = data.azurerm_function_app_host_keys.products_keys.default_function_key
    }
  }
}

resource "azurerm_api_management_api_policy" "api_policy" {
  api_management_name = azurerm_api_management.apim_workshop.name
  api_name            = azurerm_api_management_api.apim_api_workshop.name
  resource_group_name = azurerm_resource_group.rg_workshop.name

  xml_content = <<XML
 <policies>
    <inbound>
        <set-backend-service backend-id="${azurerm_api_management_backend.apim_backend_workshop.name}"/>
        <cors allow-credentials="false">
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>PUT</method>
            </allowed-methods>
        </cors>
        <base/>
    </inbound>
    <backend>
        <base/>
    </backend>
    <outbound>
        <base/>yes
    </outbound>
    <on-error>
        <base/>
    </on-error>
 </policies>
XML
}

resource "azurerm_api_management_api_operation" "get_products" {
  resource_group_name = azurerm_resource_group.rg_workshop.name
  api_management_name = azurerm_api_management.apim_workshop.name
  api_name            = azurerm_api_management_api.apim_api_workshop.name
  display_name        = "Get Products"
  method              = "GET"
  operation_id        = "get-products"
  url_template        = "/products"
}

resource "azurerm_api_management_api_operation" "get_product_by_id" {
  resource_group_name = azurerm_resource_group.rg_workshop.name
  api_management_name = azurerm_api_management.apim_workshop.name
  api_name            = azurerm_api_management_api.apim_api_workshop.name
  display_name        = "Get Product by ID"
  method              = "GET"
  operation_id        = "get-product-by-id"
  url_template        = "/products/{productId}"

  template_parameter {
    name     = "productId"
    type     = "number"
    required = true
  }
}

resource "azurerm_api_management_api_operation" "create_product" {
  resource_group_name = azurerm_resource_group.rg_workshop.name
  api_management_name = azurerm_api_management.apim_workshop.name
  api_name            = azurerm_api_management_api.apim_api_workshop.name
  display_name        = "Create Product"
  method              = "POST"
  operation_id        = "create"
  url_template        = "/product"
}