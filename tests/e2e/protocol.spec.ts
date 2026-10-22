// Garde-fous du protocole, vérifiés directement auprès de Keycloak

import { expect, test } from "@playwright/test";
import { APP_URL, OIDC_URL, env } from "./helpers";

const authorize = (params: Record<string, string>) =>
  `${OIDC_URL}/auth?${new URLSearchParams({
    client_id: "notes-web",
    response_type: "code",
    scope: "openid",
    redirect_uri: `${APP_URL}/callback`,
    ...params,
  })}`;

test("une demande d'autorisation sans PKCE est rejetée", async ({ request }) => {
  const response = await request.get(authorize({}), { maxRedirects: 0 });
  expect(response.status()).toBe(302);

  const redirect = new URL(response.headers().location);
  expect(redirect.searchParams.get("error")).toBe("invalid_request");
  expect(redirect.searchParams.get("error_description")).toContain("code_challenge_method");
});

test("une adresse de retour non déclarée est refusée", async ({ request }) => {
  const response = await request.get(
    authorize({
      redirect_uri: "https://attaquant.example/callback",
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
    }),
    { maxRedirects: 0 },
  );
  // Keycloak affiche une erreur au lieu de rediriger vers l'adresse inconnue
  expect(response.status()).toBe(400);
});

test("l'échange direct identifiant / mot de passe est désactivé", async ({ request }) => {
  const response = await request.post(`${OIDC_URL}/token`, {
    form: {
      grant_type: "password",
      client_id: "notes-web",
      client_secret: env("NOTES_WEB_CLIENT_SECRET"),
      username: "alice",
      password: env("ALICE_PASSWORD"),
    },
  });
  expect(response.status()).toBe(400);
  expect((await response.json()).error).toBe("unauthorized_client");
});
