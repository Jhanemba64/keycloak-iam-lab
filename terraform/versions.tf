terraform {
  required_version = ">= 1.9"

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# Authentification par le compte de service « terraform » créé au premier démarrage de Keycloak
provider "keycloak" {
  url           = var.keycloak_url
  realm         = "master"
  client_id     = "terraform"
  client_secret = var.keycloak_client_secret
}
