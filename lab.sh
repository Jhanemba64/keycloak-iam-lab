#!/usr/bin/env bash
# Pilotage du laboratoire : ./lab.sh up | test | down | reset | passwords
set -euo pipefail
cd "$(dirname "$0")"

# Secrets du laboratoire, générés une fois et jamais versionnés
init_env() {
  [ -f .env ] && return
  umask 077
  {
    echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
    echo "KEYCLOAK_ADMIN_CLIENT_SECRET=$(openssl rand -hex 32)"
    echo "NOTES_WEB_CLIENT_SECRET=$(openssl rand -hex 32)"
    echo "SESSION_SECRET=$(openssl rand -hex 32)"
  } > .env
  echo "Secrets générés dans .env"
}

terraform_apply() {
  export TF_VAR_keycloak_client_secret="$KEYCLOAK_ADMIN_CLIENT_SECRET"
  export TF_VAR_notes_web_client_secret="$NOTES_WEB_CLIENT_SECRET"
  terraform -chdir=terraform init -input=false >/dev/null
  terraform -chdir=terraform apply -input=false -auto-approve
}

case "${1:-}" in
  up)
    init_env
    set -a; . ./.env; set +a
    docker compose up -d --wait postgres keycloak
    terraform_apply
    docker compose up -d --wait --build app
    echo
    echo "Application : http://localhost:3000"
    echo "Comptes de test : ./lab.sh passwords"
    ;;
  test)
    # Playwright tourne dans son image officielle, branché sur la pile réseau de Keycloak
    set -a; . ./.env; set +a
    ALICE_PASSWORD=$(terraform -chdir=terraform output -raw alice_password)
    BOB_PASSWORD=$(terraform -chdir=terraform output -raw bob_password)
    export ALICE_PASSWORD BOB_PASSWORD
    host_dir=$(pwd -W 2>/dev/null || pwd) # chemin Windows sous Git Bash
    # Image Playwright de la même version que la dépendance des tests
    playwright=$(sed -n 's/.*"@playwright\/test": "\([0-9.]*\)".*/\1/p' tests/package.json)
    mkdir -p tests/playwright-report
    MSYS_NO_PATHCONV=1 docker run --rm \
      --network "container:$(docker compose ps -q keycloak)" \
      -e CI -e ALICE_PASSWORD -e BOB_PASSWORD -e KEYCLOAK_ADMIN_CLIENT_SECRET -e NOTES_WEB_CLIENT_SECRET \
      -v "$host_dir/tests:/src:ro" -v "$host_dir/tests/playwright-report:/report" \
      "mcr.microsoft.com/playwright:v${playwright}-noble" \
      bash -c 'cp -r /src /work && cd /work && npm ci --no-audit --no-fund --loglevel=error &&
               npx playwright test; status=$?; cp -r playwright-report/. /report/; exit $status'
    ;;
  passwords)
    for user in alice bob; do
      echo "$user : $(terraform -chdir=terraform output -raw "${user}_password")"
    done
    ;;
  down)
    docker compose down
    ;;
  reset)
    # Repart de zéro : base Keycloak, état Terraform et secrets
    docker compose down -v
    rm -f .env terraform/terraform.tfstate terraform/terraform.tfstate.backup
    ;;
  *)
    echo "Usage : $0 up | test | down | reset | passwords" >&2
    exit 1
    ;;
esac
