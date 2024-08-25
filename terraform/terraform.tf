terraform {
  backend "local" {}

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.99.0"

    }

    azapi = {
      source = "azure/azapi"
      version = "~> 1.4.0"
    }
  }

}
