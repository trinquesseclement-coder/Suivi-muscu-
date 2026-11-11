// Supabase met en pause les projets gratuits après 7 jours sans activité.
// Cette fonction planifiée fait une petite requête chaque jour pour l'éviter
// (utile pendant les vacances). Elle utilise les mêmes variables que l'appli.
export default async () => {
  const url = process.env.VITE_SUPABASE_URL
  const key = process.env.VITE_SUPABASE_ANON_KEY
  if (!url || !key) return new Response('Supabase non configuré', { status: 200 })
  const res = await fetch(`${url}/rest/v1/profiles?select=id&limit=1`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
  })
  console.log('keepalive', res.status)
  return new Response(`ok ${res.status}`)
}

export const config = { schedule: '@daily' }
