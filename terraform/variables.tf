variable "keycloak_url" {
  description = "URL publique de Keycloak"
  type        = string
  default     = "http://localhost:8080"
}

variable "keycloak_client_secret" {
  description = "Secret du compte de service d'administration « terraform » (fourni par lab.sh)"
  type        = string
  sensitive   = true
}

variable "app_url" {
  description = "URL publique de l'application Notes"
  type        = string
  default     = "http://localhost:3000"
}

variable "notes_web_client_secret" {
  description = "Secret du client OIDC de l'application (fourni par lab.sh)"
  type        = string
  sensitive   = true
}
