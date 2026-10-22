# Client OIDC de l'application Notes, en modèle BFF (Backend for Frontend) :
# le serveur de l'application échange le code et garde les jetons, le navigateur n'a qu'un cookie de session.

resource "keycloak_openid_client" "notes_web" {
  realm_id  = keycloak_realm.demo.id
  client_id = "notes-web"
  name      = "Application Notes"
  enabled   = true

  access_type   = "CONFIDENTIAL"
  client_secret = var.notes_web_client_secret

  # Seul le flux Authorization Code est ouvert, avec PKCE obligatoire
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false
  pkce_code_challenge_method   = "S256"

  # Redirections exactes, sans joker
  valid_redirect_uris             = ["${var.app_url}/callback"]
  valid_post_logout_redirect_uris = ["${var.app_url}/"]
  web_origins                     = []

  # Les jetons ne portent que les rôles attribués explicitement à ce client (voir plus bas)
  full_scope_allowed = false
}

resource "keycloak_generic_role_mapper" "notes_web_reader" {
  realm_id  = keycloak_realm.demo.id
  client_id = keycloak_openid_client.notes_web.id
  role_id   = keycloak_role.notes_reader.id
}

resource "keycloak_generic_role_mapper" "notes_web_admin" {
  realm_id  = keycloak_realm.demo.id
  client_id = keycloak_openid_client.notes_web.id
  role_id   = keycloak_role.notes_admin.id
}

# Méthodes d'authentification utilisées (mot de passe, OTP, passkey…) dans le jeton d'identité
resource "keycloak_generic_protocol_mapper" "notes_web_amr" {
  realm_id        = keycloak_realm.demo.id
  client_id       = keycloak_openid_client.notes_web.id
  name            = "amr"
  protocol        = "openid-connect"
  protocol_mapper = "oidc-amr-mapper"
  config = {
    "id.token.claim"            = "true"
    "access.token.claim"        = "true"
    "introspection.token.claim" = "true"
    "userinfo.token.claim"      = "true"
  }
}
