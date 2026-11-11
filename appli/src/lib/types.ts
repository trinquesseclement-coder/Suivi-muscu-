export type Kind = 'muscu' | 'cardio'

/** Comment on fait l'exercice. */
export type Posture = 'fauteuil' | 'transfert' | 'debout'

export type Muscle =
  | 'pecs'
  | 'dos'
  | 'epaules'
  | 'biceps'
  | 'triceps'
  | 'quadris'
  | 'ischios'
  | 'fessiers'
  | 'mollets'
  | 'abdos'
  | 'cardio'

export type Equipment = 'machine' | 'disques' | 'poulie' | 'smith' | 'halteres' | 'cardio'

export interface Exercise {
  id: string
  name: string
  kind: Kind
  muscle: Muscle
  posture: Posture
  /** Il faut quelqu'un pour charger/décharger les disques ou installer. */
  help: boolean
  equipment: Equipment
  /** Pas de charge par défaut pour les +/- (kg). */
  step?: number
  note?: string
  custom?: boolean
  deleted?: boolean
}

export interface Profile {
  id: string
  name: string
  /** 1 = vert, 2 = orange : sert aux graphiques et aux pastilles. */
  slot: 1 | 2
  /** Photo de profil, carrée et compressée (data URL JPEG ~20 Ko). */
  avatar?: string
  /** A besoin qu'on l'aide à charger les disques (affiche « Aide <l'autre> »). */
  needsHelp?: boolean
}

export interface SetEntry {
  kg: number
  reps: number
  done: boolean
}

export interface CardioEntry {
  minutes: number
  distanceKm?: number
  calories?: number
  level?: number
  done: boolean
}

export interface SessionItem {
  id: string
  exerciseId: string
  sets: SetEntry[]
  cardio?: CardioEntry
  note?: string
}

export type SessionStatus = 'planned' | 'done'

export interface Session {
  id: string
  ownerId: string
  createdBy: string
  /** YYYY-MM-DD */
  date: string
  title: string
  status: SessionStatus
  items: SessionItem[]
  notes?: string
  /** Ressenti global de 1 à 10. */
  rpe?: number
  durationMin?: number
  /** Horodatage de la première série cochée. */
  startedAt?: string
  /** Horodatage du bouton « Terminer ». */
  endedAt?: string
  /** Même valeur pour les séances planifiées ensemble. */
  groupId?: string
  deleted?: boolean
  updatedAt: string
}
