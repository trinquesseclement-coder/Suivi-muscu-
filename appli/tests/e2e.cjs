/**
 * Test de bout en bout (Playwright, iPhone simulé) avec un faux Supabase local :
 *  1. mode local : Clément et Jules notent une séance sur le même téléphone
 *  2. passage en ligne : les séances de Clément passent sur son compte, celles de Jules sont mises de côté
 *  3. Jules s'inscrit et importe le fichier
 *  4. séance sans réseau, puis retour du réseau : tout part au serveur et Jules la voit
 * Lancer : npm run test:e2e
 */
const { chromium, devices } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const S = __dirname + '/.tmp', U = 'http://localhost:4175/';
const ok = (n, c, x = '') => { console.log((c ? 'OK  ' : 'FAIL') + ' ' + n + (x ? ' — ' + x : '')); if (!c) process.exitCode = 1; };
const serve = (dir) => spawn('node', [__dirname + '/static.cjs', dir, '4175'], { stdio: 'ignore' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
async function signUp(page, who, name) {
  await page.getByRole('button', { name: 'Créer un compte' }).first().click();
  await page.getByLabel('Email').fill(who + '@test.fr');
  await page.getByLabel('Mot de passe').fill('secret123');
  await page.getByRole('button', { name: 'Créer le compte' }).click();
  await page.waitForTimeout(1500);
  if (await page.getByLabel('Prénom').count()) {
    await page.getByLabel('Prénom').fill(name);
    await page.getByRole('button', { name: 'C’est parti' }).click();
    await page.waitForTimeout(1500);
  }
}
async function serverRows(table) {
  // lecture directe du faux serveur avec un jeton valide
  const r = await fetch('http://localhost:54321/auth/v1/token?grant_type=password', { method: 'POST', body: JSON.stringify({ email: 'reader@test.fr' }) });
  const { access_token } = await r.json();
  return (await fetch('http://localhost:54321/rest/v1/' + table + '?select=*', { headers: { Authorization: 'Bearer ' + access_token } })).json();
}
(async () => {
  const browser = await chromium.launch();
  const errs = [];
  const opts = { ...devices['iPhone 13'], serviceWorkers: 'block' };

  // ---------- 1. Mode local : Clément fait une séance, Jules aussi sur le même téléphone
  let srv = serve(S + '/dist-local'); await wait(600);
  const cCtx = await browser.newContext(opts);
  const c = await cCtx.newPage();
  c.on('pageerror', (e) => errs.push('C ' + e.message));
  await c.goto(U); await c.waitForTimeout(400);
  await c.getByRole('button', { name: 'Séance libre' }).first().click(); await c.waitForTimeout(300);
  await c.getByRole('button', { name: 'Ajouter un exercice' }).click();
  await c.getByRole('button', { name: /^Chest press Pectoraux/ }).click();
  await c.getByRole('button', { name: /^Ajouter \(1\)/ }).click(); await c.waitForTimeout(200);
  for (let i = 0; i < 7; i++) await c.getByRole('button', { name: 'Série 1 charge plus 5' }).click();
  await c.getByRole('button', { name: 'Valider la série 1' }).click(); await c.waitForTimeout(300);
  // Jules sur le même téléphone
  await c.goto(U + '#/reglages'); await c.waitForTimeout(200);
  await c.getByRole('group', { name: 'Profil actif' }).getByRole('button', { name: 'Jules' }).click();
  await c.goto(U + '#/'); await c.waitForTimeout(200);
  await c.getByRole('button', { name: 'Séance libre' }).first().click(); await c.waitForTimeout(300);
  await c.getByRole('button', { name: 'Ajouter un exercice' }).click();
  await c.getByRole('button', { name: /^Hack squat/ }).click();
  await c.getByRole('button', { name: /^Ajouter \(1\)/ }).click(); await c.waitForTimeout(200);
  await c.getByRole('button', { name: 'Valider la série 1' }).click(); await c.waitForTimeout(300);
  await c.goto(U + '#/reglages'); await c.waitForTimeout(200);
  await c.getByRole('group', { name: 'Profil actif' }).getByRole('button', { name: 'Clément' }).click();
  const localCount = await c.evaluate(() => Object.keys(JSON.parse(localStorage.getItem('suivi:cache:v1')).sessions).length);
  ok('Mode local : 2 séances notées', localCount === 2, String(localCount));

  // ---------- 2. Passage en ligne (même adresse, nouvelle version avec Supabase)
  srv.kill(); await wait(300); srv = serve(S + '/dist-cloud'); await wait(600);
  await c.goto(U); await c.waitForTimeout(800);
  await signUp(c, 'clement', 'Clément');
  const onboard = await c.getByLabel('Prénom').count();
  ok('Profil repris du mode local (pas de question « Prénom »)', onboard === 0);
  await c.waitForTimeout(1500);
  let rows = await serverRows('sessions');
  const cId = (await serverRows('profiles')).find((p) => p.name === 'Clément')?.id;
  const mine = rows.filter((r) => r.owner_id === cId);
  ok('Séance de Clément envoyée au serveur sous son compte', mine.length === 1 && mine[0].data.items[0].sets[0].kg === 35, JSON.stringify(mine.map((m) => m.data.items[0].sets[0].kg)));
  ok('Aucune séance « local-* » envoyée au serveur', !rows.some((r) => String(r.owner_id).startsWith('local-')));
  ok('Sauvegarde de sécurité gardée', await c.evaluate(() => !!localStorage.getItem('suivi:backup')));
  const exportRaw = await c.evaluate(() => localStorage.getItem('suivi:partner-export'));
  ok('Séance de Jules mise de côté pour lui', !!exportRaw && Object.keys(JSON.parse(exportRaw).sessions).length === 1);
  await c.goto(U + '#/reglages'); await c.waitForTimeout(300);
  ok('Carte « Exporter pour … » visible dans Réglages', await c.getByRole('button', { name: /Exporter pour/ }).isVisible());
  fs.writeFileSync(S + '/export-jules.json', exportRaw);

  // ---------- 3. Jules s'inscrit sur son téléphone et importe le fichier
  const jCtx = await browser.newContext(opts);
  const j = await jCtx.newPage();
  j.on('pageerror', (e) => errs.push('J ' + e.message));
  await j.goto(U); await j.waitForTimeout(800);
  await signUp(j, 'jules', 'Jules');
  await j.goto(U + '#/reglages'); await j.waitForTimeout(300);
  await j.locator('input[type=file][accept="application/json"]').setInputFiles(S + '/export-jules.json');
  j.once('dialog', (d) => d.accept());
  await j.waitForTimeout(2000);
  rows = await serverRows('sessions');
  const jId = (await serverRows('profiles')).find((p) => p.name === 'Jules')?.id;
  ok('Import : la séance de Jules est à son nom sur le serveur', rows.filter((r) => r.owner_id === jId).length === 1);
  const jProfile = (await serverRows('profiles')).find((p) => p.name === 'Jules');
  ok('Jules a le profil n°2', jProfile?.slot === 2, 'slot ' + jProfile?.slot);

  // ---------- 4. Séance sans réseau au sous-sol, puis retour du réseau
  // Clément termine sa première séance (bilan) avant la suivante
  await c.goto(U + '#/'); await c.waitForTimeout(500);
  await c.getByRole('button', { name: /En cours/ }).first().click(); await c.waitForTimeout(300);
  await c.getByRole('button', { name: 'Terminer' }).click();
  await c.getByRole('button', { name: 'Enregistrer' }).click(); await c.waitForTimeout(800);
  await c.goto(U + '#/'); await c.waitForTimeout(500);
  await cCtx.setOffline(true);
  await c.getByRole('button', { name: 'Séance libre', exact: true }).click(); await c.waitForTimeout(300);
  await c.getByRole('button', { name: 'Ajouter un exercice' }).click();
  await c.getByRole('button', { name: /^Chest press Pectoraux/ }).click();
  await c.getByRole('button', { name: /^Ajouter \(1\)/ }).click(); await c.waitForTimeout(300);
  const prefill = await c.getByRole('textbox', { name: 'Série 1 charge' }).inputValue();
  ok('Hors ligne : charge reprise de la dernière fois (35)', prefill === '35', prefill);
  await c.getByRole('button', { name: 'Série 1 charge plus 5' }).click();
  await c.getByRole('button', { name: 'Valider la série 1' }).click(); await c.waitForTimeout(800);
  const pill = await c.locator('.sync-pill').count() ? null : null;
  const before = (await serverRows('sessions')).filter((r) => r.owner_id === cId).length;
  ok('Hors ligne : rien n’est parti au serveur', before === 1, String(before));
  ok('Hors ligne : modification en attente', await c.evaluate(() => JSON.parse(localStorage.getItem('suivi:outbox:v1')).sessions.length) > 0);
  await cCtx.setOffline(false);
  await c.evaluate(() => window.dispatchEvent(new Event('online')));
  await c.waitForTimeout(2500);
  const after = (await serverRows('sessions')).filter((r) => r.owner_id === cId);
  ok('Retour du réseau : séance envoyée (40 kg)', after.length === 2 && after.some((r) => r.data.items[0].sets[0].kg === 40));
  // Jules voit la séance de Clément
  await j.goto(U + '#/'); await j.reload(); await j.waitForTimeout(1500);
  const jHome = await j.locator('main').innerText();
  ok('Jules voit la séance de Clément', /Clément/.test(jHome) && /Séance libre/.test(jHome));
  ok('Aucune erreur JavaScript', errs.length === 0, errs.join(' | '));
  await browser.close(); srv.kill();
})().catch((e) => { console.error(e); process.exit(1); });
