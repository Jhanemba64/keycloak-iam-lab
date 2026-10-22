import { expect, type Page } from "@playwright/test";
import * as OTPAuth from "otpauth";

export const APP_URL = "http://localhost:3000";
export const KEYCLOAK_URL = "http://localhost:8080";
export const OIDC_URL = `${KEYCLOAK_URL}/realms/demo/protocol/openid-connect`;

export function env(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Variable d'environnement manquante : ${name} (lancer ./lab.sh test)`);
  return value;
}

const passwords: Record<string, () => string> = {
  alice: () => env("ALICE_PASSWORD"),
  bob: () => env("BOB_PASSWORD"),
};

// Secrets OTP récupérés à l'enrôlement, et dernier code utilisé par compte
const otpSecrets = new Map<string, string>();
const lastPeriod = new Map<string, number>();

// Keycloak refuse un code déjà utilisé : si besoin, on attend la période suivante
async function totpCode(username: string): Promise<string> {
  const totp = new OTPAuth.TOTP({
    secret: OTPAuth.Secret.fromBase32(otpSecrets.get(username)!),
    algorithm: "SHA1",
    digits: 6,
    period: 30,
  });
  while (totp.counter() === lastPeriod.get(username)) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  lastPeriod.set(username, totp.counter());
  return totp.generate();
}

export async function submitPassword(page: Page, username: string, password: string) {
  await page.goto("/login");
  await page.locator("#username").fill(username);
  await page.locator("#password").fill(password);
  await page.locator("#kc-login").click();
}

// Connexion complète : mot de passe, puis enrôlement OTP (première fois) ou code OTP
export async function login(page: Page, username: string) {
  await submitPassword(page, username, passwords[username]());

  const enrolment = page.locator("#totp");
  const otpForm = page.locator("#otp");
  await expect(enrolment.or(otpForm)).toBeVisible();

  if (await enrolment.isVisible()) {
    await page.locator("a[href*='mode=manual']").click();
    const secret = (await page.locator("#kc-totp-secret-key").textContent()) ?? "";
    otpSecrets.set(username, secret.replace(/\s/g, ""));
    await page.locator("#totp").fill(await totpCode(username));
    await page.locator("#userLabel").fill("Téléphone de test");
    await page.locator("#totp").press("Enter");
  } else {
    await otpForm.fill(await totpCode(username));
    await otpForm.press("Enter");
  }

  await page.waitForURL(`${APP_URL}/`);
  await expect(page.locator("#username")).toHaveText(username);
}

export async function logout(page: Page) {
  await page.getByRole("button", { name: "Se déconnecter" }).click();
  await expect(page.getByRole("link", { name: "Se connecter" })).toBeVisible();
}
