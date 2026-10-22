// Gabarit HTML minimal ; toute donnée issue des jetons est échappée avant affichage

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

export function page(title, body, user) {
  const logout = user
    ? `<form method="post" action="/logout"><button type="submit">Se déconnecter</button></form>`
    : "";
  return `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <link rel="stylesheet" href="/style.css">
</head>
<body>
  <header><a href="/">Notes</a>${logout}</header>
  <main>
    <h1>${escapeHtml(title)}</h1>
    ${body}
  </main>
</body>
</html>`;
}
