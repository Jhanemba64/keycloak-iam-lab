# Rôles applicatifs et groupes : les droits s'attribuent par groupe, jamais utilisateur par utilisateur

resource "keycloak_role" "notes_reader" {
  realm_id    = keycloak_realm.demo.id
  name        = "notes-reader"
  description = "Consulter les notes"
}

# Rôle composite : un administrateur est aussi lecteur
resource "keycloak_role" "notes_admin" {
  realm_id        = keycloak_realm.demo.id
  name            = "notes-admin"
  description     = "Administrer l'application Notes"
  composite_roles = [keycloak_role.notes_reader.id]
}

resource "keycloak_group" "readers" {
  realm_id = keycloak_realm.demo.id
  name     = "lecteurs"
}

resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.demo.id
  name     = "administrateurs"
}

resource "keycloak_group_roles" "readers" {
  realm_id = keycloak_realm.demo.id
  group_id = keycloak_group.readers.id
  role_ids = [keycloak_role.notes_reader.id]
}

resource "keycloak_group_roles" "admins" {
  realm_id = keycloak_realm.demo.id
  group_id = keycloak_group.admins.id
  role_ids = [keycloak_role.notes_admin.id]
}
