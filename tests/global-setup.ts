// Remet les comptes de test dans leur état initial, pour que les tests soient rejouables :
// facteurs OTP et passkeys supprimés, OTP de nouveau exigé, blocage anti-force brute levé.

import { KEYCLOAK_URL, env } from "./e2e/helpers";

async function adminToken(): Promise<string> {
  const response = await fetch(`${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token`, {
    method: "POST",
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: "terraform",
      client_secret: env("KEYCLOAK_ADMIN_CLIENT_SECRET"),
    }),
  });
  if (!response.ok) throw new Error(`Jeton d'administration refusé : ${response.status}`);
  return (await response.json()).access_token;
}

export default async function globalSetup() {
  const token = await adminToken();
  const admin = async (path: string, method = "GET", body?: unknown) => {
    const response = await fetch(`${KEYCLOAK_URL}/admin/realms/demo${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) throw new Error(`${method} ${path} : ${response.status}`);
    return response.status === 200 ? response.json() : undefined;
  };

  for (const username of ["alice", "bob"]) {
    const [user] = await admin(`/users?username=${username}&exact=true`);
    for (const credential of await admin(`/users/${user.id}/credentials`)) {
      if (credential.type !== "password") {
        await admin(`/users/${user.id}/credentials/${credential.id}`, "DELETE");
      }
    }
    await admin(`/users/${user.id}`, "PUT", { requiredActions: ["CONFIGURE_TOTP"] });
    await admin(`/attack-detection/brute-force/users/${user.id}`, "DELETE");
    await admin(`/users/${user.id}/logout`, "POST");
  }
}
