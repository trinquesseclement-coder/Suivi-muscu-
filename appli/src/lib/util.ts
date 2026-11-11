export function uid(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  // Repli pour les vieux navigateurs
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16)
  })
}

/** Date locale au format YYYY-MM-DD (pas en UTC, sinon décalage le soir). */
export function isoDate(d: Date = new Date()): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function parseDate(s: string): Date {
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function addDays(s: string, n: number): string {
  const d = parseDate(s)
  d.setDate(d.getDate() + n)
  return isoDate(d)
}

/** Lundi de la semaine de la date donnée. */
export function weekStart(s: string): string {
  const d = parseDate(s)
  const dow = (d.getDay() + 6) % 7 // lundi = 0
  d.setDate(d.getDate() - dow)
  return isoDate(d)
}

const DAY = new Intl.DateTimeFormat('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
const DAY_SHORT = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })
const DM = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' })

export function fmtDay(s: string): string {
  const today = isoDate()
  if (s === today) return 'Aujourd’hui'
  if (s === addDays(today, -1)) return 'Hier'
  if (s === addDays(today, 1)) return 'Demain'
  return cap(DAY.format(parseDate(s)))
}

export function fmtDayShort(s: string): string {
  return cap(DAY_SHORT.format(parseDate(s)))
}

export function fmtDM(s: string): string {
  return DM.format(parseDate(s))
}

export function cap(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1)
}

const NUM = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 1 })
export function fmtNum(n: number): string {
  return NUM.format(n)
}

/** 12 400 kg -> "12,4 t" ; 850 -> "850 kg" */
export function fmtTonnage(kg: number): string {
  if (kg >= 1000) return `${NUM.format(kg / 1000)} t`
  return `${NUM.format(Math.round(kg))} kg`
}

export function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n))
}

export function round(n: number, step: number) {
  return Math.round(n / step) * step
}
