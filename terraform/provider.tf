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
provider "azurerm" {
  features {
        key_vault {
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_secrets          = true
      purge_soft_delete_on_destroy          = true
    }
  }
}

provider "azapi" {}


provider "template" {}
