/**
 * Stockage « local d'abord » :
 *  - tout est gardé sur le téléphone (localStorage), donc l'appli marche sans réseau
 *    au fond de la salle ;
 *  - en mode cloud, chaque modification part dans une file d'attente qui est
 *    envoyée à Supabase dès que possible, et les modifs de l'autre arrivent en
 *    temps réel.
 *  - en mode local (pas de Supabase configuré), les deux profils vivent sur le
 *    même appareil : pratique pour tester.
 */
import { useSyncExternalStore } from 'react'
import type { RealtimeChannel, Session as AuthSession, SupabaseClient } from '@supabase/supabase-js'
import { BASE_EXERCISES } from '../data/exercises'
import type { Exercise, Profile, Session } from './types'
import { getSupabase } from './supabase'

type Table = 'sessions' | 'exercises' | 'profiles'

interface Cache {
  profiles: Record<string, Profile>
  sessions: Record<string, Session>
  /** Exercices perso + corrections du catalogue de base. */
  exercises: Record<string, Exercise>
}

interface Outbox {
  sessions: string[]
  exercises: string[]
  profiles: string[]
}

export type SyncStatus = 'local' | 'synced' | 'syncing' | 'offline' | 'error'

export interface State {
  mode: 'local' | 'cloud'
  /** Mode cloud : connecté ? */
  authed: boolean
  authReady: boolean
  /** Premier chargement depuis le serveur terminé (ou mode local). */
  loaded: boolean
  email?: string
  meId: string | null
  profiles: Profile[]
  sessions: Session[]
  exercises: Exercise[]
  exerciseById: Record<string, Exercise>
  sync: SyncStatus
  pending: number
  lastError?: string
}

const K_CACHE = 'suivi:cache:v1'
const K_OUTBOX = 'suivi:outbox:v1'
const K_ME = 'suivi:me'
const K_CURSOR = 'suivi:cursor'

const LOCAL_PROFILES: Profile[] = [
  { id: 'local-clement', name: 'Clément', slot: 1 },
  { id: 'local-jules', name: 'Jules', slot: 2 },
]

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function write(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    /* stockage plein ou bloqué : on garde en mémoire */
  }
}

// ---------- état interne ----------

const sb: SupabaseClient | null = getSupabase()

let cache: Cache = read<Cache>(K_CACHE, { profiles: {}, sessions: {}, exercises: {} })
let outbox: Outbox = read<Outbox>(K_OUTBOX, { sessions: [], exercises: [], profiles: [] })
let meId: string | null = read<string | null>(K_ME, null)
let auth: { ready: boolean; session: AuthSession | null } = { ready: !sb, session: null }
let sync: SyncStatus = sb ? 'syncing' : 'local'
let lastError: string | undefined
let loaded = !sb

if (!sb) {
  for (const p of LOCAL_PROFILES) if (!cache.profiles[p.id]) cache.profiles[p.id] = p
  if (!meId || !cache.profiles[meId]) meId = LOCAL_PROFILES[0].id
}

const listeners = new Set<() => void>()
let snapshot: State = buildSnapshot()

function buildSnapshot(): State {
  const merged: Record<string, Exercise> = {}
  for (const e of BASE_EXERCISES) merged[e.id] = e
  for (const e of Object.values(cache.exercises)) merged[e.id] = { ...merged[e.id], ...e }
  const exercises = Object.values(merged)
    .filter((e) => !e.deleted)
    .sort((a, b) => a.name.localeCompare(b.name, 'fr'))
  const profiles = Object.values(cache.profiles).sort((a, b) => a.slot - b.slot || a.name.localeCompare(b.name))
  const sessions = Object.values(cache.sessions)
    .filter((s) => !s.deleted)
    .sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : b.updatedAt.localeCompare(a.updatedAt)))
  return {
    mode: sb ? 'cloud' : 'local',
    authed: sb ? !!auth.session : true,
    authReady: auth.ready,
    loaded,
    email: auth.session?.user.email,
    meId,
    profiles,
    sessions,
    exercises,
    exerciseById: merged,
    sync,
    pending: outbox.sessions.length + outbox.exercises.length + outbox.profiles.length,
    lastError,
  }
}

function emit() {
  snapshot = buildSnapshot()
  listeners.forEach((l) => l())
}

function persist() {
  write(K_CACHE, cache)
  write(K_OUTBOX, outbox)
  write(K_ME, meId)
}

function enqueue(table: Table, id: string) {
  if (!sb) return
  if (!outbox[table].includes(id)) outbox[table].push(id)
  scheduleFlush()
}

// ---------- API publique ----------

export const store = {
  subscribe(l: () => void) {
    listeners.add(l)
    return () => listeners.delete(l)
  },
  get: () => snapshot,

  /** Mode local uniquement : changer de profil sur le même téléphone. */
  switchLocalProfile(id: string) {
    if (sb) return
    meId = id
    persist()
    emit()
  },

  saveSession(s: Session) {
    const next = { ...s, updatedAt: new Date().toISOString() }
    cache.sessions[s.id] = next
    enqueue('sessions', s.id)
    persist()
    emit()
  },

  saveSessions(list: Session[]) {
    const now = new Date().toISOString()
    for (const s of list) {
      cache.sessions[s.id] = { ...s, updatedAt: now }
      enqueue('sessions', s.id)
    }
    persist()
    emit()
  },

  deleteSession(id: string) {
    const s = cache.sessions[id]
    if (!s) return
    cache.sessions[id] = { ...s, deleted: true, updatedAt: new Date().toISOString() }
    enqueue('sessions', id)
    persist()
    emit()
  },

  saveExercise(e: Exercise) {
    cache.exercises[e.id] = e
    enqueue('exercises', e.id)
    persist()
    emit()
  },

  saveProfile(p: Profile) {
    cache.profiles[p.id] = p
    enqueue('profiles', p.id)
    persist()
    emit()
  },

  /** Export JSON de toutes les données (sauvegarde). */
  exportData(): string {
    return JSON.stringify({ version: 1, exportedAt: new Date().toISOString(), ...cache }, null, 2)
  },

  importData(json: string) {
    const data = JSON.parse(json) as Partial<Cache>
    for (const raw of Object.values(data.sessions ?? {})) {
      // En ligne, une séance venue du mode local (fichier exporté) devient la mienne
      const s =
        sb && meId && isLocalId(raw.ownerId)
          ? { ...raw, ownerId: meId, createdBy: isLocalId(raw.createdBy) ? meId : raw.createdBy }
          : raw
      cache.sessions[s.id] = s
      enqueue('sessions', s.id)
    }
    for (const e of Object.values(data.exercises ?? {})) {
      cache.exercises[e.id] = e
      enqueue('exercises', e.id)
    }
    if (!sb) for (const p of Object.values(data.profiles ?? {})) cache.profiles[p.id] = p
    persist()
    emit()
  },

  async signIn(email: string, password: string) {
    if (!sb) return
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) throw error
  },

  async signUp(email: string, password: string) {
    if (!sb) return
    const { data, error } = await sb.auth.signUp({ email, password })
    if (error) throw error
    if (!data.session) throw new Error('Compte créé : confirme ton email puis connecte-toi (ou désactive la confirmation dans Supabase).')
  },

  async signOut() {
    if (!sb) return
    await sb.auth.signOut()
    cache = { profiles: {}, sessions: {}, exercises: {} }
    outbox = { sessions: [], exercises: [], profiles: [] }
    meId = null
    localStorage.removeItem(K_CURSOR)
    persist()
    emit()
  },

  syncNow: () => pull(true).then(flush),
}

export function useStore(): State {
  return useSyncExternalStore(store.subscribe, store.get, store.get)
}

// ---------- synchro Supabase ----------

interface SessionRow {
  id: string
  owner_id: string
  created_by: string
  date: string
  status: Session['status']
  title: string
  group_id: string | null
  deleted: boolean
  data: Pick<Session, 'items' | 'notes' | 'rpe' | 'durationMin' | 'startedAt' | 'endedAt'>
  updated_at: string
}

interface ExerciseRow {
  id: string
  data: Exercise
  deleted: boolean
  updated_at: string
}

interface ProfileRow {
  id: string
  name: string
  slot: 1 | 2
  avatar: string | null
  needs_help: boolean | null
  updated_at: string
}

const toSessionRow = (s: Session): Omit<SessionRow, 'updated_at'> => ({
  id: s.id,
  owner_id: s.ownerId,
  created_by: s.createdBy,
  date: s.date,
  status: s.status,
  title: s.title,
  group_id: s.groupId ?? null,
  deleted: !!s.deleted,
  data: { items: s.items, notes: s.notes, rpe: s.rpe, durationMin: s.durationMin, startedAt: s.startedAt, endedAt: s.endedAt },
})

const fromSessionRow = (r: SessionRow): Session => ({
  id: r.id,
  ownerId: r.owner_id,
  createdBy: r.created_by,
  date: r.date,
  status: r.status,
  title: r.title,
  groupId: r.group_id ?? undefined,
  deleted: r.deleted,
  items: r.data?.items ?? [],
  notes: r.data?.notes,
  rpe: r.data?.rpe,
  durationMin: r.data?.durationMin,
  startedAt: r.data?.startedAt,
  endedAt: r.data?.endedAt,
  updatedAt: r.updated_at,
})

let flushTimer: ReturnType<typeof setTimeout> | undefined
let flushing = false
let channel: RealtimeChannel | null = null

function setSync(s: SyncStatus, err?: string) {
  sync = s
  lastError = err
  emit()
}

function scheduleFlush(delay = 600) {
  clearTimeout(flushTimer)
  flushTimer = setTimeout(() => void flush(), delay)
}

async function flush() {
  if (!sb || !auth.session || flushing) return
  const total = outbox.sessions.length + outbox.exercises.length + outbox.profiles.length
  if (total === 0) {
    if (sync !== 'error') setSync(navigator.onLine ? 'synced' : 'offline')
    return
  }
  if (!navigator.onLine) return setSync('offline')
  flushing = true
  setSync('syncing')
  try {
    // Les profils d'abord (clé étrangère des séances)
    let rejected = 0
    rejected += await pushTable('profiles', (id) => {
      const p = cache.profiles[id]
      return p && { id: p.id, name: p.name, slot: p.slot, avatar: p.avatar ?? null, needs_help: p.needsHelp ?? null }
    })
    rejected += await pushTable('exercises', (id) => {
      const e = cache.exercises[id]
      return e && { id: e.id, data: e, deleted: !!e.deleted }
    })
    rejected += await pushTable('sessions', (id) => {
      const x = cache.sessions[id]
      return x && toSessionRow(x)
    })
    if (rejected) {
      // On récupère la version du serveur pour les lignes refusées.
      persist()
      flushing = false
      await pull(true)
      setSync('error', `${rejected} modification(s) refusée(s) par le serveur (droits insuffisants).`)
      return
    }
    persist()
    setSync('synced')
  } catch (e) {
    setSync(navigator.onLine ? 'error' : 'offline', errMsg(e))
    scheduleFlush(15000)
  } finally {
    flushing = false
  }
  // Des modifs ont pu arriver pendant l'envoi
  if (outbox.sessions.length + outbox.exercises.length + outbox.profiles.length > 0 && sync === 'synced') scheduleFlush()
}

/**
 * Envoie la file d'une table. Si le lot est refusé, on réessaie ligne par ligne :
 * une ligne interdite (RLS) est abandonnée pour ne pas bloquer toutes les autres.
 * Retourne le nombre de lignes abandonnées. Lève une erreur si c'est le réseau.
 */
async function pushTable(table: Table, toRow: (id: string) => object | undefined): Promise<number> {
  if (!sb || !outbox[table].length) return 0
  const ids = [...outbox[table]]
  const rows = ids.map((id) => [id, toRow(id)] as const)
  const valid = rows.filter(([, r]) => r)
  const { error } = await sb.from(table).upsert(valid.map(([, r]) => r!))
  if (!error) {
    outbox[table] = outbox[table].filter((id) => !ids.includes(id))
    return 0
  }
  if (!isPermissionError(error)) throw error
  let rejected = 0
  for (const [id, row] of valid) {
    const res = await sb.from(table).upsert(row!)
    if (res.error && !isPermissionError(res.error)) throw res.error
    if (res.error) rejected++
    outbox[table] = outbox[table].filter((x) => x !== id)
  }
  outbox[table] = outbox[table].filter((id) => !rows.some(([rid, r]) => rid === id && !r))
  return rejected
}

function errMsg(e: unknown): string {
  if (e && typeof e === 'object' && 'message' in e) return String((e as { message: unknown }).message)
  return String(e)
}

function isPermissionError(e: { code?: string; message?: string }) {
  return e.code === '42501' || /row-level security/i.test(e.message ?? '')
}

let pulling = false
async function pull(full = false) {
  if (!sb || !auth.session || pulling) return
  if (!navigator.onLine) return setSync('offline')
  pulling = true
  try {
    // Petite marge de recouvrement : une transaction peut être validée après une autre plus récente.
    const cursor: string | null = full ? null : read<string | null>(K_CURSOR, null)
    const since = cursor ? new Date(new Date(cursor).getTime() - 5 * 60_000).toISOString() : null
    let maxTs = cursor ?? ''

    const profilesQ = sb.from('profiles').select('*')
    const sessionsQ = since ? sb.from('sessions').select('*').gt('updated_at', since) : sb.from('sessions').select('*')
    const exercisesQ = since ? sb.from('exercises').select('*').gt('updated_at', since) : sb.from('exercises').select('*')
    const [p, s, e] = await Promise.all([profilesQ, sessionsQ, exercisesQ])
    if (p.error) throw p.error
    if (s.error) throw s.error
    if (e.error) throw e.error

    for (const r of p.data as ProfileRow[]) {
      if (!outbox.profiles.includes(r.id)) cache.profiles[r.id] = { id: r.id, name: r.name, slot: r.slot, avatar: r.avatar ?? undefined, needsHelp: r.needs_help ?? undefined }
    }
    for (const r of s.data as SessionRow[]) {
      if (r.updated_at > maxTs) maxTs = r.updated_at
      if (!outbox.sessions.includes(r.id)) cache.sessions[r.id] = fromSessionRow(r)
    }
    for (const r of e.data as ExerciseRow[]) {
      if (r.updated_at > maxTs) maxTs = r.updated_at
      if (!outbox.exercises.includes(r.id)) cache.exercises[r.id] = { ...r.data, id: r.id, deleted: r.deleted }
    }
    if (maxTs) write(K_CURSOR, maxTs)
    persist()
    if (sync !== 'syncing') setSync('synced')
    else emit()
  } catch (err) {
    setSync('error', errMsg(err))
  } finally {
    pulling = false
  }
}

let pullTimer: ReturnType<typeof setTimeout> | undefined
function schedulePull() {
  clearTimeout(pullTimer)
  pullTimer = setTimeout(() => void pull(), 400)
}

function startRealtime() {
  if (!sb || channel) return
  channel = sb
    .channel('suivi-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'sessions' }, schedulePull)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'exercises' }, schedulePull)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, schedulePull)
    .subscribe()
}

function stopRealtime() {
  if (sb && channel) void sb.removeChannel(channel)
  channel = null
}

let initializedFor: string | null = null

const K_BACKUP = 'suivi:backup'
export const K_PARTNER_EXPORT = 'suivi:partner-export'
const isLocalId = (id: string | null | undefined) => !!id && id.startsWith('local-')

/** Copie de sécurité avant d'effacer le cache (récupérable à la main si besoin). */
function backupCache() {
  try {
    if (Object.keys(cache.sessions).length) {
      localStorage.setItem(K_BACKUP, JSON.stringify({ savedAt: new Date().toISOString(), meId, ...cache }))
    }
  } catch {
    /* stockage plein */
  }
}

interface LocalData {
  me: string
  cache: Cache
}

function takeLocalData(): LocalData | null {
  const hasLocal = Object.values(cache.sessions).some((s) => isLocalId(s.ownerId))
  if (!hasLocal) return null
  return { me: isLocalId(meId) ? meId! : 'local-clement', cache: JSON.parse(JSON.stringify(cache)) as Cache }
}

/**
 * Premier passage en ligne : les séances faites en mode local deviennent celles du
 * compte connecté. Celles de l'autre profil local sont mises de côté pour être
 * exportées vers son téléphone (Réglages).
 */
function migrateLocal(local: LocalData, userId: string) {
  const mine: Session[] = []
  const partner: Record<string, Session> = {}
  for (const s of Object.values(local.cache.sessions)) {
    if (!isLocalId(s.ownerId)) continue
    if (s.ownerId === local.me) {
      mine.push({ ...s, ownerId: userId, createdBy: isLocalId(s.createdBy) ? userId : s.createdBy })
    } else {
      partner[s.id] = s
    }
  }
  for (const s of mine) {
    if (!cache.sessions[s.id]) {
      cache.sessions[s.id] = s
      enqueue('sessions', s.id)
    }
  }
  for (const e of Object.values(local.cache.exercises)) {
    if (!cache.exercises[e.id]) {
      cache.exercises[e.id] = e
      enqueue('exercises', e.id)
    }
  }
  const lp = local.cache.profiles[local.me]
  if (lp && !cache.profiles[userId]) {
    const taken = new Set(Object.values(cache.profiles).map((p) => p.slot))
    cache.profiles[userId] = {
      id: userId,
      name: lp.name,
      slot: taken.has(1) ? 2 : 1,
      avatar: lp.avatar,
      needsHelp: lp.needsHelp ?? lp.slot === 1,
    }
    enqueue('profiles', userId)
  }
  if (Object.keys(partner).length) {
    try {
      localStorage.setItem(K_PARTNER_EXPORT, JSON.stringify({ version: 1, sessions: partner }))
    } catch {
      /* stockage plein : elles restent dans la sauvegarde */
    }
  }
  persist()
}

async function onAuth(session: AuthSession | null) {
  auth = { ready: true, session }
  if (session) {
    const userId = session.user.id
    if (initializedFor === userId) return emit()
    // Données du mode local (avant Supabase) : on les met de côté pour les reprendre.
    const local = takeLocalData()
    if (meId && meId !== userId) {
      // Un autre compte (ou le mode local) était sur ce téléphone : sauvegarde, puis on repart à zéro.
      backupCache()
      cache = { profiles: {}, sessions: {}, exercises: {} }
      outbox = { sessions: [], exercises: [], profiles: [] }
      localStorage.removeItem(K_CURSOR)
    }
    initializedFor = userId
    meId = userId
    // Déjà des données en cache (hors ligne à la salle) : pas besoin d'attendre le serveur.
    if (cache.profiles[userId]) loaded = true
    persist()
    emit()
    await pull(true)
    if (local) migrateLocal(local, userId)
    loaded = true
    emit()
    await flush()
    startRealtime()
  } else {
    initializedFor = null
    loaded = false
    stopRealtime()
    emit()
  }
}

if (sb) {
  sb.auth.onAuthStateChange((event, session) => {
    // Ne jamais appeler Supabase directement dans ce callback (risque de blocage) : on décale.
    if (event === 'INITIAL_SESSION' || event === 'SIGNED_IN' || event === 'SIGNED_OUT') {
      setTimeout(() => void onAuth(session), 0)
    } else if (session) {
      auth = { ready: true, session }
    }
  })
  window.addEventListener('online', () => {
    void pull().then(flush)
  })
  window.addEventListener('offline', () => setSync('offline'))
  // Filet de sécurité si le temps réel décroche (réseau de la salle, mise en veille…)
  setInterval(() => {
    if (document.visibilityState === 'visible') void pull().then(flush)
  }, 30_000)
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') void pull().then(flush)
  })
}
