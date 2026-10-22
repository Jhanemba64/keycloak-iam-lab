import { expect, test } from "@playwright/test";
import { env, login, logout, submitPassword } from "./helpers";

test.describe.configure({ mode: "serial" });

test("première connexion d'alice : l'OTP est imposé, puis droits de lecture seulement", async ({ page }) => {
  await login(page, "alice");
  await expect(page.locator("#roles")).toHaveText("notes-reader");
  // L'OTP est configuré par une action requise, pas vérifié par l'étape OTP du flux
  await expect(page.locator("#amr")).toHaveText("pwd");

  await page.goto("/notes");
  await expect(page.locator("#notes li")).toHaveCount(3);

  const admin = await page.goto("/admin");
  expect(admin?.status()).toBe(403);
});

test("bob, administrateur, accède aussi à l'administration", async ({ page }) => {
  await login(page, "bob");
  // notes-admin est un rôle composite qui inclut notes-reader
  await expect(page.locator("#roles")).toHaveText("notes-admin notes-reader");

  const admin = await page.goto("/admin");
  expect(admin?.status()).toBe(200);
  await expect(page.locator("#admin")).toBeVisible();
});

test("connexion suivante avec mot de passe et OTP, puis déconnexion complète", async ({ page }) => {
  await login(page, "alice");
  await expect(page.locator("#amr")).toHaveText("otp pwd");
  await logout(page);

  // Pas de reconnexion silencieuse : Keycloak redemande les identifiants
  await page.goto("/login");
  await expect(page.locator("#username")).toBeVisible();
});

test("alice enregistre une passkey puis se connecte sans mot de passe ni OTP", async ({ page }) => {
  // Authentificateur virtuel de Chrome : clé résidente avec vérification de l'utilisateur
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("WebAuthn.enable");
  await cdp.send("WebAuthn.addVirtualAuthenticator", {
    options: {
      protocol: "ctap2",
      transport: "internal",
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  });

  await login(page, "alice");
  page.on("dialog", (dialog) => dialog.accept("Passkey de test"));
  await page.goto("/passkey");
  await page.locator("#registerWebAuthn").click();
  await page.waitForURL(/localhost:3000\/$/);
  await logout(page);

  // Interface conditionnelle : Keycloak propose la passkey par autoremplissage dès l'affichage
  // du formulaire, et l'authentificateur la présente aussitôt. Ni mot de passe, ni OTP.
  await page.goto("/login");
  await page.waitForURL(/localhost:3000\/$/);
  await expect(page.locator("#username")).toHaveText("alice");
  // hwk : preuve de possession d'une clé cryptographique (RFC 8176)
  await expect(page.locator("#amr")).toHaveText("hwk");
});

test("la protection anti-force brute bloque le compte après 5 échecs", async ({ page }) => {
  for (let attempt = 0; attempt < 5; attempt++) {
    await submitPassword(page, "bob", "mauvais-mot-de-passe");
    await expect(page.locator("#input-error-username")).toBeVisible();
  }

  // Même le bon mot de passe est refusé pendant le blocage, avec un message volontairement neutre
  await submitPassword(page, "bob", env("BOB_PASSWORD"));
  await expect(page.locator("#input-error-username")).toBeVisible();
  await expect(page).not.toHaveURL(/localhost:3000/);
});
