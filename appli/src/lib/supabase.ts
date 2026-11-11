import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const K_CONFIG = 'suivi:supabase'

export interface SupabaseConfig {
  url: string
  key: string
}

/** Priorité aux variables d'environnement (Netlify), sinon config saisie dans Réglages. */
export function getSupabaseConfig(): (SupabaseConfig & { source: 'env' | 'manual' }) | null {
  const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
  const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
  if (url && key) return { url, key, source: 'env' }
  try {
    const raw = localStorage.getItem(K_CONFIG)
    if (raw) {
      const c = JSON.parse(raw) as SupabaseConfig
      if (c.url && c.key) return { ...c, source: 'manual' }
    }
  } catch {
    /* ignore */
  }
  return null
}

export function setManualSupabaseConfig(c: SupabaseConfig | null) {
  if (c) localStorage.setItem(K_CONFIG, JSON.stringify(c))
  else localStorage.removeItem(K_CONFIG)
}

let client: SupabaseClient | null | undefined

export function getSupabase(): SupabaseClient | null {
  if (client !== undefined) return client
  const c = getSupabaseConfig()
  client = c ? createClient(c.url, c.key, { auth: { persistSession: true, autoRefreshToken: true } }) : null
  return client
}
