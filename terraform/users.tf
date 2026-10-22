# Comptes de démonstration, mots de passe aléatoires conformes à la politique du realm.
# L'OTP est imposé à la première connexion.

locals {
  users = {
    alice = { first_name = "Alice", last_name = "Martin", group = keycloak_group.readers.id }
    bob   = { first_name = "Bob", last_name = "Durand", group = keycloak_group.admins.id }
  }
}

resource "random_password" "user" {
  for_each = local.users

  length           = 20
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#%*-_=+"
}

resource "keycloak_user" "user" {
  for_each = local.users

  realm_id       = keycloak_realm.demo.id
  username       = each.key
  email          = "${each.key}@example.com"
  email_verified = true
  first_name     = each.value.first_name
  last_name      = each.value.last_name

  initial_password {
    value     = random_password.user[each.key].result
    temporary = false
  }

  required_actions = ["CONFIGURE_TOTP"]

  # Keycloak retire l'action une fois l'OTP configuré : Terraform ne doit pas la remettre
  lifecycle {
    ignore_changes = [required_actions]
  }

  depends_on = [keycloak_required_action.configure_totp]
}

resource "keycloak_user_groups" "user" {
  for_each = local.users

  realm_id  = keycloak_realm.demo.id
  user_id   = keycloak_user.user[each.key].id
  group_ids = [each.value.group]
}
