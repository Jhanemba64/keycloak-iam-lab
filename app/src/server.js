// Application « Notes » : client OIDC confidentiel en modèle BFF (Backend for Frontend).
// Le serveur mène le flux Authorization Code + PKCE, garde les jetons en session
// et n'expose au navigateur qu'un cookie de session HttpOnly.

import express from "express";
import session from "express-session";
import * as oidc from "openid-client";
import { page, escapeHtml } from "./views.js";

const { ISSUER, CLIENT_ID, CLIENT_SECRET, APP_URL, SESSION_SECRET } = process.env;
const PORT = Number(process.env.PORT ?? 3000);
const REDIRECT_URI = `${APP_URL}/callback`;
const SESSION_COOKIE = "notes.sid";
const APP_ROLES = ["notes-reader", "notes-admin"];

// Laboratoire en HTTP sur localhost : openid-client exige HTTPS sauf autorisation explicite
const discoveryOptions = ISSUER.startsWith("http://")
  ? { execute: [oidc.allowInsecureRequests] }
  : undefined;

async function discover() {
  for (let attempt = 1; ; attempt++) {
    try {
      return await oidc.discovery(new URL(ISSUER), CLIENT_ID, CLIENT_SECRET, undefined, discoveryOptions);
    } catch (error) {
      if (attempt === 30) throw error;
      console.log(`Issuer indisponible (${error.message}), nouvel essai dans 2 s`);
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
}

const config = await discover();

// Le jeton d'accès vient directement du serveur d'autorisation par le canal serveur :
// sa lecture suffit ici. Une API qui le recevrait d'un tiers devrait vérifier sa signature.
function appRoles(accessToken) {
  const payload = JSON.parse(Buffer.from(accessToken.split(".")[1], "base64url").toString());
  return (payload.realm_access?.roles ?? []).filter((role) => APP_ROLES.includes(role)).sort();
}

const app = express();
app.disable("x-powered-by");

app.use((req, res, next) => {
  res.set({
    "Content-Security-Policy": `default-src 'self'; form-action 'self' ${new URL(ISSUER).origin}; frame-ancestors 'none'; base-uri 'none'; object-src 'none'`,
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-store",
  });
  next();
});

app.get("/healthz", (req, res) => res.send("ok"));
app.use(express.static("public"));

app.use(
  session({
    name: SESSION_COOKIE,
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: "lax",
      secure: APP_URL.startsWith("https://"),
      maxAge: 30 * 60 * 1000,
    },
  }),
);

// Redirection vers Keycloak : PKCE (S256), state et nonce propres à chaque connexion
async function redirectToKeycloak(req, res, extraParams = {}) {
  const codeVerifier = oidc.randomPKCECodeVerifier();
  const state = oidc.randomState();
  const nonce = oidc.randomNonce();
  req.session.pending = { codeVerifier, state, nonce };

  const url = oidc.buildAuthorizationUrl(config, {
    redirect_uri: REDIRECT_URI,
    scope: "openid profile email",
    code_challenge: await oidc.calculatePKCECodeChallenge(codeVerifier),
    code_challenge_method: "S256",
    state,
    nonce,
    ...extraParams,
  });
  res.redirect(url.href);
}

app.get("/login", (req, res) => redirectToKeycloak(req, res));

// Enregistrement d'une passkey par une action initiée par l'application (AIA)
app.get("/passkey", (req, res) =>
  redirectToKeycloak(req, res, { kc_action: "webauthn-register-passwordless" }),
);

app.get("/callback", async (req, res, next) => {
  const pending = req.session.pending;
  if (!pending) return res.redirect("/");

  try {
    const tokens = await oidc.authorizationCodeGrant(config, new URL(req.originalUrl, APP_URL), {
      pkceCodeVerifier: pending.codeVerifier,
      expectedState: pending.state,
      expectedNonce: pending.nonce,
    });
    const claims = tokens.claims();

    // Nouvel identifiant de session après authentification (anti fixation de session)
    req.session.regenerate((error) => {
      if (error) return next(error);
      req.session.user = {
        username: claims.preferred_username,
        name: claims.name,
        roles: appRoles(tokens.access_token),
        amr: [...(claims.amr ?? [])].sort(),
      };
      req.session.idToken = tokens.id_token;
      res.redirect("/");
    });
  } catch (error) {
    next(error);
  }
});

app.post("/logout", (req, res) => {
  const idToken = req.session.idToken;
  req.session.destroy(() => {
    res.clearCookie(SESSION_COOKIE);
    if (!idToken) return res.redirect("/");

    // Déconnexion initiée par l'application : ferme aussi la session Keycloak
    const url = oidc.buildEndSessionUrl(config, {
      id_token_hint: idToken,
      post_logout_redirect_uri: `${APP_URL}/`,
    });
    res.redirect(url.href);
  });
});

function requireRole(role) {
  return (req, res, next) => {
    const user = req.session.user;
    if (!user) return res.redirect("/login");
    if (!user.roles.includes(role)) {
      return res.status(403).send(
        page("Accès refusé", `<p>Le rôle <code>${escapeHtml(role)}</code> est nécessaire pour cette page.</p>`, user),
      );
    }
    next();
  };
}

app.get("/", (req, res) => {
  const user = req.session.user;
  if (!user) {
    return res.send(
      page("Notes", `<p>Application de démonstration protégée par Keycloak.</p>
        <p><a class="button" href="/login">Se connecter</a></p>`),
    );
  }
  const list = (values) => values.map((v) => `<code>${escapeHtml(v)}</code>`).join(" ") || "aucun";
  res.send(
    page("Notes", `<dl>
        <dt>Utilisateur</dt><dd id="username">${escapeHtml(user.username)}</dd>
        <dt>Nom</dt><dd>${escapeHtml(user.name ?? "")}</dd>
        <dt>Rôles</dt><dd id="roles">${list(user.roles)}</dd>
        <dt>Méthodes d'authentification</dt><dd id="amr">${list(user.amr)}</dd>
      </dl>
      <p><a href="/notes">Mes notes</a> · <a href="/admin">Administration</a> · <a href="/passkey">Ajouter une passkey</a></p>`, user),
  );
});

app.get("/notes", requireRole("notes-reader"), (req, res) => {
  res.send(
    page("Mes notes", `<ul id="notes">
        <li>Revue des accès du trimestre</li>
        <li>Rotation des secrets clients</li>
        <li>Activer les passkeys pour toute l'équipe</li>
      </ul>`, req.session.user),
  );
});

app.get("/admin", requireRole("notes-admin"), (req, res) => {
  res.send(page("Administration", `<p id="admin">Espace réservé au rôle <code>notes-admin</code>.</p>`, req.session.user));
});

app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).send(page("Erreur", "<p>La connexion a échoué. Réessayez depuis l'accueil.</p>"));
});

app.listen(PORT, () => console.log(`Notes en écoute sur ${APP_URL}`));
