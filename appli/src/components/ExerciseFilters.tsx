import { useMemo, useState } from 'react'
import { MUSCLE_LABEL } from '../data/exercises'
import type { Exercise, Muscle } from '../lib/types'

export interface Filters {
  q: string
  chair: boolean
  noTransfer: boolean
  help: 'all' | 'with' | 'without'
  muscle: Muscle | 'all'
}

export const DEFAULT_FILTERS: Filters = { q: '', chair: false, noTransfer: false, help: 'all', muscle: 'all' }

const norm = (s: string) =>
  s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')

export function applyFilters(list: Exercise[], f: Filters) {
  const q = norm(f.q.trim())
  return list.filter((e) => {
    if (q && !norm(e.name).includes(q) && !norm(MUSCLE_LABEL[e.muscle]).includes(q)) return false
    if (f.chair && e.posture !== 'fauteuil') return false
    if (f.noTransfer && e.posture === 'debout') return false
    if (f.help === 'with' && !e.help) return false
    if (f.help === 'without' && e.help) return false
    if (f.muscle !== 'all' && e.muscle !== f.muscle) return false
    return true
  })
}

/** Filtres mémorisés sur le téléphone (sauf la recherche) : le filtre « fauteuil » reste actif. */
export function useFilters(storageKey: string) {
  const [filters, setFilters] = useState<Filters>(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey) ?? '{}') as Partial<Filters>
      return { ...DEFAULT_FILTERS, ...saved, q: '' }
    } catch {
      return DEFAULT_FILTERS
    }
  })
  const update = (f: Filters) => {
    setFilters(f)
    try {
      const { q: _q, ...rest } = f
      localStorage.setItem(storageKey, JSON.stringify(rest))
    } catch {
      /* stockage indisponible : filtres non mémorisés */
    }
  }
  return [filters, update] as const
}

export function ExerciseFilters({
  value,
  onChange,
  helperName,
}: {
  value: Filters
  onChange: (f: Filters) => void
  helperName?: string
}) {
  const set = (patch: Partial<Filters>) => onChange({ ...value, ...patch })
  const muscles = useMemo(() => Object.keys(MUSCLE_LABEL) as Muscle[], [])
  return (
    <div className="stack" style={{ gap: 8 }}>
      <input
        className="input"
        type="search"
        placeholder="Chercher une machine…"
        value={value.q}
        onChange={(e) => set({ q: e.target.value })}
        aria-label="Chercher"
      />
      <div className="chips" role="group" aria-label="Filtres d’accessibilité">
        <button className="chip" aria-pressed={value.chair} onClick={() => set({ chair: !value.chair })}>
          Depuis le fauteuil
        </button>
        <button className="chip" aria-pressed={value.noTransfer} onClick={() => set({ noTransfer: !value.noTransfer })}>
          Assis (sans debout)
        </button>
        <button
          className="chip"
          aria-pressed={value.help === 'with'}
          onClick={() => set({ help: value.help === 'with' ? 'all' : 'with' })}
        >
          Avec {helperName ?? 'aide'}
        </button>
        <button
          className="chip"
          aria-pressed={value.help === 'without'}
          onClick={() => set({ help: value.help === 'without' ? 'all' : 'without' })}
        >
          Sans aide
        </button>
      </div>
      <div className="chips" role="group" aria-label="Groupe musculaire">
        <button className="chip" aria-pressed={value.muscle === 'all'} onClick={() => set({ muscle: 'all' })}>
          Tout
        </button>
        {muscles.map((m) => (
          <button key={m} className="chip" aria-pressed={value.muscle === m} onClick={() => set({ muscle: m })}>
            {MUSCLE_LABEL[m]}
          </button>
        ))}
      </div>
    </div>
  )
}
