import type { Exercise, Muscle, Session, SessionItem } from './types'
import { addDays, weekStart } from './util'

/** 1RM estimé (Epley). Au-delà de 12 reps l'estimation devient peu fiable. */
export function e1rm(kg: number, reps: number): number {
  if (reps <= 0 || kg <= 0) return 0
  if (reps === 1) return kg
  return kg * (1 + Math.min(reps, 12) / 30)
}

export const doneSets = (it: SessionItem) => it.sets.filter((s) => s.done && s.reps > 0)

export function itemTonnage(it: SessionItem): number {
  return doneSets(it).reduce((t, s) => t + s.kg * s.reps, 0)
}

export function sessionTonnage(s: Session): number {
  return s.items.reduce((t, it) => t + itemTonnage(it), 0)
}

export function sessionCardioMin(s: Session, byId: Record<string, Exercise>): number {
  return s.items.reduce((t, it) => {
    if (byId[it.exerciseId]?.kind !== 'cardio' || !it.cardio?.done) return t
    return t + (it.cardio.minutes || 0)
  }, 0)
}

export function sessionSetCount(s: Session): number {
  return s.items.reduce((t, it) => t + doneSets(it).length, 0)
}

export interface WeekStats {
  week: string // lundi YYYY-MM-DD
  sessions: number
  tonnage: number
  sets: number
  cardioMin: number
  setsByMuscle: Partial<Record<Muscle, number>>
}

export function weeklyStats(
  sessions: Session[],
  ownerId: string,
  byId: Record<string, Exercise>,
  weeks: number,
  today: string,
): WeekStats[] {
  const first = addDays(weekStart(today), -7 * (weeks - 1))
  const out: WeekStats[] = []
  for (let i = 0; i < weeks; i++) {
    out.push({ week: addDays(first, 7 * i), sessions: 0, tonnage: 0, sets: 0, cardioMin: 0, setsByMuscle: {} })
  }
  const index = new Map(out.map((w, i) => [w.week, i]))
  for (const s of sessions) {
    if (s.ownerId !== ownerId || s.status !== 'done') continue
    const i = index.get(weekStart(s.date))
    if (i === undefined) continue
    const w = out[i]
    w.sessions++
    w.tonnage += sessionTonnage(s)
    w.cardioMin += sessionCardioMin(s, byId)
    for (const it of s.items) {
      const ex = byId[it.exerciseId]
      if (!ex || ex.kind !== 'muscu') continue
      const n = doneSets(it).length
      w.sets += n
      w.setsByMuscle[ex.muscle] = (w.setsByMuscle[ex.muscle] ?? 0) + n
    }
  }
  return out
}

export interface ExercisePoint {
  date: string
  sessionId: string
  topKg: number
  topReps: number
  e1rm: number
  tonnage: number
}

/** Historique d'un exercice pour une personne, du plus ancien au plus récent. */
export function exerciseHistory(sessions: Session[], ownerId: string, exerciseId: string): ExercisePoint[] {
  const pts: ExercisePoint[] = []
  for (const s of sessions) {
    if (s.ownerId !== ownerId || s.status !== 'done') continue
    for (const it of s.items) {
      if (it.exerciseId !== exerciseId) continue
      const sets = doneSets(it)
      if (!sets.length) continue
      let top = sets[0]
      let best = 0
      for (const st of sets) {
        if (st.kg > top.kg || (st.kg === top.kg && st.reps > top.reps)) top = st
        best = Math.max(best, e1rm(st.kg, st.reps))
      }
      pts.push({ date: s.date, sessionId: s.id, topKg: top.kg, topReps: top.reps, e1rm: best, tonnage: itemTonnage(it) })
    }
  }
  return pts.sort((a, b) => a.date.localeCompare(b.date))
}

export interface CardioPoint {
  date: string
  minutes: number
  distanceKm?: number
  calories?: number
  level?: number
}

export function cardioHistory(sessions: Session[], ownerId: string, exerciseId: string): CardioPoint[] {
  const pts: CardioPoint[] = []
  for (const s of sessions) {
    if (s.ownerId !== ownerId || s.status !== 'done') continue
    for (const it of s.items) {
      if (it.exerciseId !== exerciseId || !it.cardio?.done) continue
      pts.push({ date: s.date, ...it.cardio })
    }
  }
  return pts.sort((a, b) => a.date.localeCompare(b.date))
}

/** Dernière fois où la personne a fait l'exercice (séance terminée). */
export function lastPerformance(sessions: Session[], ownerId: string, exerciseId: string, excludeSessionId?: string) {
  for (const s of sessions) {
    // sessions est trié du plus récent au plus ancien
    if (s.ownerId !== ownerId || s.status !== 'done' || s.id === excludeSessionId) continue
    const it = s.items.find((i) => i.exerciseId === exerciseId && (doneSets(i).length || i.cardio?.done))
    if (it) return { session: s, item: it }
  }
  return null
}

export interface PR {
  exerciseId: string
  kg: number
  reps: number
  e1rm: number
  date: string
}

/** Meilleure perf (1RM estimé) par exercice. */
export function personalRecords(sessions: Session[], ownerId: string): Record<string, PR> {
  const prs: Record<string, PR> = {}
  for (const s of sessions) {
    if (s.ownerId !== ownerId || s.status !== 'done') continue
    for (const it of s.items) {
      for (const st of doneSets(it)) {
        const v = e1rm(st.kg, st.reps)
        const cur = prs[it.exerciseId]
        if (!cur || v > cur.e1rm || (v === cur.e1rm && s.date < cur.date)) {
          prs[it.exerciseId] = { exerciseId: it.exerciseId, kg: st.kg, reps: st.reps, e1rm: v, date: s.date }
        }
      }
    }
  }
  return prs
}

/** Records battus pendant cette séance (par rapport à tout ce qui précède). */
export function sessionPRs(sessions: Session[], session: Session): string[] {
  const before = sessions.filter(
    (s) => s.ownerId === session.ownerId && s.id !== session.id && s.status === 'done' && s.date <= session.date,
  )
  const prev = personalRecords(before, session.ownerId)
  const out: string[] = []
  for (const it of session.items) {
    const best = Math.max(0, ...doneSets(it).map((s) => e1rm(s.kg, s.reps)))
    const p = prev[it.exerciseId]
    if (best > 0 && p && best > p.e1rm + 0.01) out.push(it.exerciseId)
  }
  return out
}
