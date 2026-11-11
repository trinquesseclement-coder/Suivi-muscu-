import { useSyncExternalStore } from 'react'

export type Route =
  | { name: 'home' }
  | { name: 'planning'; week?: string }
  | { name: 'stats' }
  | { name: 'machines' }
  | { name: 'settings' }
  | { name: 'session'; id: string }
  | { name: 'plan'; id?: string; date?: string }

function parse(hash: string): Route {
  const [path, query = ''] = hash.replace(/^#\/?/, '').split('?')
  const params = new URLSearchParams(query)
  const [a, b] = path.split('/')
  switch (a) {
    case 'planning':
      return { name: 'planning', week: params.get('semaine') ?? undefined }
    case 'charge':
      return { name: 'stats' }
    case 'machines':
      return { name: 'machines' }
    case 'reglages':
      return { name: 'settings' }
    case 'seance':
      return b ? { name: 'session', id: b } : { name: 'home' }
    case 'plan':
      return { name: 'plan', id: b && b !== 'nouveau' ? b : undefined, date: params.get('date') ?? undefined }
    default:
      return { name: 'home' }
  }
}

export function href(r: Route): string {
  switch (r.name) {
    case 'home':
      return '#/'
    case 'planning':
      return r.week ? `#/planning?semaine=${r.week}` : '#/planning'
    case 'stats':
      return '#/charge'
    case 'machines':
      return '#/machines'
    case 'settings':
      return '#/reglages'
    case 'session':
      return `#/seance/${r.id}`
    case 'plan':
      return `#/plan/${r.id ?? 'nouveau'}${r.date ? `?date=${r.date}` : ''}`
  }
}

let current = parse(location.hash)
const listeners = new Set<() => void>()
window.addEventListener('hashchange', () => {
  current = parse(location.hash)
  listeners.forEach((l) => l())
  window.scrollTo(0, 0)
})

export function navigate(r: Route, opts: { replace?: boolean } = {}) {
  const h = href(r)
  if (opts.replace) {
    history.replaceState(null, '', h)
    current = parse(h)
    listeners.forEach((l) => l())
    window.scrollTo(0, 0)
  } else {
    depth++
    location.hash = h
  }
}

/** Nombre de navigations internes empilées : évite de sortir de l'appli sur « retour ». */
let depth = 0

export function back(fallback: Route = { name: 'home' }) {
  if (depth > 0) {
    depth--
    history.back()
  } else navigate(fallback, { replace: true })
}

export function useRoute(): Route {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l)
      return () => listeners.delete(l)
    },
    () => current,
  )
}
