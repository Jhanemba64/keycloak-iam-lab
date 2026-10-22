import { defineConfig, devices } from "@playwright/test";

// Les tests partagent les mêmes comptes : exécution en série, sur un seul navigateur
export default defineConfig({
  testDir: "./e2e",
  globalSetup: "./global-setup.ts",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: !!process.env.CI,
  // Un code OTP ne sert qu'une fois : un test peut attendre la période suivante (30 s)
  timeout: 90_000,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: "http://localhost:3000",
    locale: "fr-FR",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
