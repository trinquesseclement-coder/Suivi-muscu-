const http = require('http');
const crypto = require('crypto');
const db = { profiles: [], sessions: [], exercises: [] };
const users = {}; // email -> id
const tokens = {}; // token -> id
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': '*', 'Access-Control-Expose-Headers': '*' };
function send(res, code, body) { res.writeHead(code, { ...cors, 'Content-Type': 'application/json' }); res.end(body === undefined ? '' : JSON.stringify(body)); }
function session(id, email) {
  const t = 'tok-' + crypto.randomUUID(); tokens[t] = id;
  const now = Math.floor(Date.now() / 1000);
  return { access_token: t, token_type: 'bearer', expires_in: 3600, expires_at: now + 3600, refresh_token: 'r-' + t,
    user: { id, email, aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() } };
}
let tick = 0;
const ts = () => new Date(Date.now() + (tick++)).toISOString();
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    if (req.method === 'OPTIONS') return send(res, 204);
    const u = new URL(req.url, 'http://x');
    const auth = (req.headers.authorization || '').replace('Bearer ', '');
    const uid = tokens[auth];
    if (u.pathname === '/auth/v1/signup' || (u.pathname === '/auth/v1/token' && u.searchParams.get('grant_type') === 'password')) {
      const { email } = JSON.parse(body);
      if (!users[email]) users[email] = crypto.randomUUID();
      return send(res, 200, session(users[email], email));
    }
    if (u.pathname === '/auth/v1/user') return uid ? send(res, 200, { id: uid, aud: 'authenticated' }) : send(res, 401, {});
    if (u.pathname === '/auth/v1/logout') return send(res, 204);
    const m = u.pathname.match(/^\/rest\/v1\/(\w+)$/);
    if (m) {
      const t = db[m[1]];
      if (!uid) return send(res, 401, { message: 'no auth' });
      if (req.method === 'GET') {
        const gt = u.searchParams.get('updated_at');
        const since = gt && gt.startsWith('gt.') ? gt.slice(3) : null;
        return send(res, 200, t.filter((r) => !since || r.updated_at > since));
      }
      if (req.method === 'POST') {
        const rows = [].concat(JSON.parse(body));
        for (const r of rows) {
          // RLS minimale sur les séances
          if (m[1] === 'sessions') {
            const ok = r.owner_id === uid || (r.created_by === uid && r.status === 'planned');
            const ex = t.find((x) => x.id === r.id);
            const okUpd = !ex || ex.owner_id === uid || (ex.created_by === uid && ex.status === 'planned');
            if (!ok || !okUpd) return send(res, 403, { code: '42501', message: 'new row violates row-level security policy' });
          }
        }
        for (const r of rows) {
          const i = t.findIndex((x) => x.id === r.id);
          const row = { ...(i >= 0 ? t[i] : {}), ...r, updated_at: ts() };
          if (i >= 0) t[i] = row; else t.push(row);
        }
        console.log('upsert', m[1], rows.length);
        return send(res, 201);
      }
    }
    send(res, 404, { message: 'not found ' + u.pathname });
  });
}).listen(54321, () => console.log('fake supabase on 54321'));
