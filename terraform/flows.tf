# Flux de connexion du navigateur, décrit en code : passkey, ou mot de passe + OTP.
#
# Le formulaire unique « identifiant / mot de passe » propose aussi la passkey (interface
# conditionnelle) et ne révèle pas si un compte existe. Deux branches conditionnelles suivent,
# selon l'identifiant réellement utilisé :
#   - passkey (clé cryptographique + vérification de l'utilisateur) : rien de plus à demander ;
#   - mot de passe : second facteur OTP obligatoire.
#
# Chaque branche déclare sa référence AMR (RFC 8176) pour que l'application sache comment
# l'utilisateur s'est authentifié (claim « amr ») : hwk pour la passkey, pwd puis otp sinon.
# Keycloak n'inclut une référence que pendant sa durée de validité (maxAge, 0 s par défaut) :
# on l'aligne sur la durée maximale de la session SSO.

locals {
  amr_max_age = tostring(10 * 3600)
}

resource "keycloak_authentication_flow" "browser_mfa" {
  realm_id    = keycloak_realm.demo.id
  alias       = "navigateur-mfa"
  description = "Passkey, ou mot de passe + OTP"
}

# Session déjà ouverte (SSO)
resource "keycloak_authentication_execution" "cookie" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_flow.browser_mfa.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_subflow" "forms" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_flow.browser_mfa.alias
  alias             = "navigateur-mfa-formulaires"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution" "login_form" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.forms.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# --- Branche passkey ---------------------------------------------------------

resource "keycloak_authentication_subflow" "passkey" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.forms.alias
  alias             = "navigateur-mfa-passkey"
  requirement       = "CONDITIONAL"
  priority          = 20
}

resource "keycloak_authentication_execution" "passkey_used" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.passkey.alias
  authenticator     = "conditional-credential"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution_config" "passkey_used" {
  realm_id     = keycloak_realm.demo.id
  execution_id = keycloak_authentication_execution.passkey_used.id
  alias        = "passkey-utilisee"
  config = {
    credentials = "webauthn-passwordless"
    included    = "true"
  }
}

resource "keycloak_authentication_execution" "passkey_amr" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.passkey.alias
  authenticator     = "allow-access-authenticator"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_authentication_execution_config" "passkey_amr" {
  realm_id     = keycloak_realm.demo.id
  execution_id = keycloak_authentication_execution.passkey_amr.id
  alias        = "amr-passkey"
  config = {
    "default.reference.value"  = "hwk"
    "default.reference.maxAge" = local.amr_max_age
  }
}

# --- Branche mot de passe ----------------------------------------------------

resource "keycloak_authentication_subflow" "password" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.forms.alias
  alias             = "navigateur-mfa-mot-de-passe"
  requirement       = "CONDITIONAL"
  priority          = 30
}

resource "keycloak_authentication_execution" "password_used" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.password.alias
  authenticator     = "conditional-credential"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution_config" "password_used" {
  realm_id     = keycloak_realm.demo.id
  execution_id = keycloak_authentication_execution.password_used.id
  alias        = "mot-de-passe-utilise"
  config = {
    credentials = "password"
    included    = "true"
  }
}

resource "keycloak_authentication_execution" "password_amr" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.password.alias
  authenticator     = "allow-access-authenticator"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_authentication_execution_config" "password_amr" {
  realm_id     = keycloak_realm.demo.id
  execution_id = keycloak_authentication_execution.password_amr.id
  alias        = "amr-mot-de-passe"
  config = {
    "default.reference.value"  = "pwd"
    "default.reference.maxAge" = local.amr_max_age
  }
}

# Second facteur, pour tout utilisateur qui a configuré son OTP. À la première connexion,
# l'OTP n'est pas encore configuré : l'action requise CONFIGURE_TOTP l'impose (voir users.tf).
resource "keycloak_authentication_subflow" "otp" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.password.alias
  alias             = "navigateur-mfa-otp"
  requirement       = "CONDITIONAL"
  priority          = 30
}

resource "keycloak_authentication_execution" "otp_configured" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.otp.alias
  authenticator     = "conditional-user-configured"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution" "otp" {
  realm_id          = keycloak_realm.demo.id
  parent_flow_alias = keycloak_authentication_subflow.otp.alias
  authenticator     = "auth-otp-form"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_authentication_execution_config" "otp_amr" {
  realm_id     = keycloak_realm.demo.id
  execution_id = keycloak_authentication_execution.otp.id
  alias        = "amr-otp"
  config = {
    "default.reference.value"  = "otp"
    "default.reference.maxAge" = local.amr_max_age
  }
}

resource "keycloak_authentication_bindings" "demo" {
  realm_id     = keycloak_realm.demo.id
  browser_flow = keycloak_authentication_flow.browser_mfa.alias

  # Le flux doit être complet avant de devenir le flux de connexion du realm
  depends_on = [
    keycloak_authentication_execution.cookie,
    keycloak_authentication_execution.login_form,
    keycloak_authentication_execution_config.passkey_used,
    keycloak_authentication_execution_config.passkey_amr,
    keycloak_authentication_execution_config.password_used,
    keycloak_authentication_execution_config.password_amr,
    keycloak_authentication_execution.otp_configured,
    keycloak_authentication_execution_config.otp_amr,
  ]
}
