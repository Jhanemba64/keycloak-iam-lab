output "issuer" {
  description = "Issuer OIDC du realm"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.demo.realm}"
}

output "alice_password" {
  description = "Mot de passe d'alice (groupe lecteurs)"
  value       = random_password.user["alice"].result
  sensitive   = true
}

output "bob_password" {
  description = "Mot de passe de bob (groupe administrateurs)"
  value       = random_password.user["bob"].result
  sensitive   = true
}
