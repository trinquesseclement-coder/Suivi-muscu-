import type { Exercise, Profile, Session, SessionItem } from './types'
import { lastPerformance } from './stats'
import { isoDate, uid } from './util'

/** Nouvel item pré-rempli avec la dernière perf de la personne (sinon 3×10 à vide). */
export function newItem(ex: Exercise, ownerId: string, sessions: Session[]): SessionItem {
  const last = lastPerformance(sessions, ownerId, ex.id)
  if (ex.kind === 'cardio') {
    const c = last?.item.cardio
    return {
      id: uid(),
      exerciseId: ex.id,
      sets: [],
      cardio: { minutes: c?.minutes ?? 15, distanceKm: c?.distanceKm, level: c?.level, calories: undefined, done: false },
    }
  }
  const prevSets = last?.item.sets.filter((s) => s.done) ?? []
  const sets = prevSets.length
    ? prevSets.map((s) => ({ kg: s.kg, reps: s.reps, done: false }))
    : [0, 1, 2].map(() => ({ kg: 0, reps: 10, done: false }))
  return { id: uid(), exerciseId: ex.id, sets }
}

/** Remet un item « à faire » en gardant les charges (pour reprendre une séance). */
export function resetItem(it: SessionItem): SessionItem {
  return {
    ...it,
    id: uid(),
    sets: it.sets.map((s) => ({ ...s, done: false })),
    cardio: it.cardio ? { ...it.cardio, done: false } : undefined,
  }
}

export function blankSession(ownerId: string, createdBy: string, date = isoDate()): Session {
  return {
    id: uid(),
    ownerId,
    createdBy,
    date,
    title: 'Séance',
    status: 'planned',
    items: [],
    updatedAt: new Date().toISOString(),
  }
}

export function isLive(s: Session): boolean {
  if (s.status !== 'done' || s.endedAt || !s.startedAt) return false
  return Date.now() - new Date(s.startedAt).getTime() < 4 * 3600_000
}

export function hasProgress(s: Session): boolean {
  return s.items.some((it) => it.sets.some((x) => x.done) || it.cardio?.done)
}

export function partnerOf(profiles: Profile[], id: string | null): Profile | undefined {
  return profiles.find((p) => p.id !== id)
}

/**
 * Qui a besoin d'aide pour les disques ? Réglage de chaque profil ; tant qu'il
 * n'est pas réglé : oui pour le profil n°1 (celui qui a créé l'appli), non sinon.
 */
export function profileNeedsHelp(p: Profile): boolean {
  return p.needsHelp ?? p.slot === 1
}

export function needsHelp(profiles: Profile[], id: string | null | undefined): boolean {
  const p = profiles.find((x) => x.id === id)
  return p ? profileNeedsHelp(p) : false
}

/** Le nom de l'aidant, identique sur les deux téléphones (« Aide Jules »). */
export function helperName(profiles: Profile[]): string | undefined {
  const helped = profiles.find((p) => needsHelp(profiles, p.id))
  return helped ? partnerOf(profiles, helped.id)?.name : undefined
}

export function titleSuggestion(items: SessionItem[], byId: Record<string, Exercise>): string {
  const groups = new Set(items.map((i) => byId[i.exerciseId]?.muscle).filter(Boolean))
  const has = (...m: string[]) => m.some((x) => groups.has(x as never))
  const upper = has('pecs', 'dos', 'epaules', 'biceps', 'triceps')
  const lower = has('quadris', 'ischios', 'fessiers', 'mollets')
  const cardio = has('cardio')
  if (upper && lower) return cardio ? 'Full body + cardio' : 'Full body'
  if (upper) {
    if (has('pecs', 'epaules', 'triceps') && !has('dos', 'biceps')) return cardio ? 'Push + cardio' : 'Push'
    if (has('dos', 'biceps') && !has('pecs', 'epaules', 'triceps')) return cardio ? 'Pull + cardio' : 'Pull'
    return cardio ? 'Haut du corps + cardio' : 'Haut du corps'
  }
  if (lower) return cardio ? 'Jambes + cardio' : 'Jambes'
  if (cardio) return 'Cardio'
  return 'Séance'
}
