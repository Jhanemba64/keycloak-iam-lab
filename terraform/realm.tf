# Realm « demo » : toute la politique de sécurité est décrite ici

resource "keycloak_realm" "demo" {
  realm        = "demo"
  display_name = "Notes"
  enabled      = true

  # HTTPS exigé pour toute connexion qui ne vient pas du réseau local
  ssl_required = "external"

  registration_allowed     = false
  reset_password_allowed   = false # pas de serveur de messagerie dans le laboratoire
  remember_me              = false
  login_with_email_allowed = true
  duplicate_emails_allowed = false

  password_policy = "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername and notEmail and passwordHistory(5)"

  # Jetons d'accès courts, sessions bornées, refresh tokens à usage unique
  access_token_lifespan    = "5m"
  sso_session_idle_timeout = "30m"
  sso_session_max_lifespan = "10h"
  revoke_refresh_token     = true
  refresh_token_max_reuse  = 0

  internationalization {
    supported_locales = ["fr", "en"]
    default_locale    = "fr"
  }

  # Codes à usage unique (applications type Google Authenticator, FreeOTP…)
  otp_policy {
    type              = "totp"
    algorithm         = "HmacSHA1"
    digits            = 6
    period            = 30
    look_ahead_window = 1
  }

  # Passkeys : connexion sans mot de passe, vérification de l'utilisateur obligatoire
  web_authn_passwordless_policy {
    relying_party_entity_name     = "Notes"
    relying_party_id              = "localhost"
    user_verification_requirement = "required"
    discoverable_credential       = "required"
    passwordless_passkeys_enabled = true
  }

  security_defenses {
    headers {
      x_frame_options                     = "SAMEORIGIN"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
      referrer_policy                     = "no-referrer"
    }

    # Blocage temporaire après 5 échecs, durée croissante jusqu'à 15 minutes
    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 5
      wait_increment_seconds           = 60
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
    }
  }
}

# Actions que Keycloak peut imposer à l'utilisateur
resource "keycloak_required_action" "configure_totp" {
  realm_id = keycloak_realm.demo.id
  alias    = "CONFIGURE_TOTP"
  enabled  = true
}

resource "keycloak_required_action" "register_passkey" {
  realm_id = keycloak_realm.demo.id
  alias    = "webauthn-register-passwordless"
  enabled  = true
}
