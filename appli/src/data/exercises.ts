import type { Equipment, Exercise, Kind, Muscle, Posture } from '../lib/types'

/**
 * Catalogue de base pour une salle très équipée.
 * La posture et l'aide sont des valeurs par défaut : chacun peut les corriger
 * dans l'onglet Machines (la correction est partagée entre vous deux).
 *
 * posture :
 *  - fauteuil  : faisable sans quitter le fauteuil (poulies, ergomètre à bras…)
 *  - transfert : il faut s'installer sur le siège de la machine
 *  - debout    : debout, appui court
 * help : disques à charger / installation à faire par Jules
 */
type Row = [id: string, name: string, muscle: Muscle, posture: Posture, help: boolean, equipment: Equipment, step?: number]

const muscu: Row[] = [
  // Poulies — en général faisables depuis le fauteuil
  ['poulie-tirage-vertical', 'Tirage vertical à la poulie', 'dos', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-tirage-horizontal', 'Tirage horizontal à la poulie', 'dos', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-tirage-unilateral', 'Tirage unilatéral à la poulie', 'dos', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-face-pull', 'Face pull', 'epaules', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-rotation-externe', 'Rotation externe d’épaule', 'epaules', 'fauteuil', false, 'poulie', 1.25],
  ['poulie-elevation-laterale', 'Élévation latérale à la poulie', 'epaules', 'fauteuil', false, 'poulie', 1.25],
  ['poulie-developpe-poitrine', 'Développé poitrine à la poulie', 'pecs', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-vis-a-vis', 'Écarté vis-à-vis', 'pecs', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-curl', 'Curl biceps à la poulie', 'biceps', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-triceps', 'Extension triceps poulie haute', 'triceps', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-triceps-nuque', 'Extension triceps au-dessus de la tête', 'triceps', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-crunch', 'Crunch à la poulie', 'abdos', 'fauteuil', false, 'poulie', 2.5],
  ['poulie-rotation-buste', 'Rotation du buste à la poulie (woodchop)', 'abdos', 'fauteuil', false, 'poulie', 2.5],

  // Machines guidées à plaques (sélecteur) — transfert sur le siège
  ['m-chest-press', 'Chest press', 'pecs', 'transfert', false, 'machine', 5],
  ['m-chest-press-incline', 'Chest press inclinée', 'pecs', 'transfert', false, 'machine', 5],
  ['m-pec-deck', 'Pec deck (butterfly)', 'pecs', 'transfert', false, 'machine', 5],
  ['m-shoulder-press', 'Développé épaules machine', 'epaules', 'transfert', false, 'machine', 5],
  ['m-elevation-laterale', 'Élévations latérales machine', 'epaules', 'transfert', false, 'machine', 2.5],
  ['m-oiseau', 'Oiseau machine (reverse pec deck)', 'epaules', 'transfert', false, 'machine', 2.5],
  ['m-lat-pulldown', 'Tirage vertical machine', 'dos', 'transfert', false, 'machine', 5],
  ['m-rowing', 'Rowing assis machine', 'dos', 'transfert', false, 'machine', 5],
  ['m-pullover', 'Pull-over machine', 'dos', 'transfert', false, 'machine', 5],
  ['m-tractions-assistees', 'Tractions assistées', 'dos', 'debout', false, 'machine', 5],
  ['m-lombaires', 'Extension lombaires machine', 'dos', 'transfert', false, 'machine', 5],
  ['m-curl', 'Curl biceps machine', 'biceps', 'transfert', false, 'machine', 2.5],
  ['m-triceps', 'Extension triceps machine', 'triceps', 'transfert', false, 'machine', 2.5],
  ['m-dips-assis', 'Dips assis machine', 'triceps', 'transfert', false, 'machine', 5],
  ['m-presse', 'Presse à cuisses', 'quadris', 'transfert', false, 'machine', 5],
  ['m-leg-extension', 'Leg extension', 'quadris', 'transfert', false, 'machine', 5],
  ['m-leg-curl-assis', 'Leg curl assis', 'ischios', 'transfert', false, 'machine', 5],
  ['m-leg-curl-allonge', 'Leg curl allongé', 'ischios', 'transfert', false, 'machine', 5],
  ['m-abducteurs', 'Abducteurs machine', 'fessiers', 'transfert', false, 'machine', 5],
  ['m-adducteurs', 'Adducteurs machine', 'quadris', 'transfert', false, 'machine', 5],
  ['m-hip-thrust', 'Hip thrust machine', 'fessiers', 'transfert', false, 'machine', 5],
  ['m-kickback', 'Kickback fessiers machine', 'fessiers', 'debout', false, 'machine', 2.5],
  ['m-mollets-assis', 'Mollets assis machine', 'mollets', 'transfert', false, 'machine', 5],
  ['m-crunch', 'Crunch machine', 'abdos', 'transfert', false, 'machine', 5],
  ['m-rotation-buste', 'Rotation du buste machine', 'abdos', 'transfert', false, 'machine', 5],

  // Machines à disques — Jules charge les poids
  ['d-chest-press', 'Chest press convergente à disques', 'pecs', 'transfert', true, 'disques', 5],
  ['d-incline-press', 'Développé incliné à disques', 'pecs', 'transfert', true, 'disques', 5],
  ['d-shoulder-press', 'Développé épaules à disques', 'epaules', 'transfert', true, 'disques', 5],
  ['d-row-isolateral', 'Rowing iso-latéral à disques', 'dos', 'transfert', true, 'disques', 5],
  ['d-lat-isolateral', 'Tirage vertical iso-latéral à disques', 'dos', 'transfert', true, 'disques', 5],
  ['d-tbar', 'T-bar row poitrine appuyée', 'dos', 'transfert', true, 'disques', 5],
  ['d-presse-45', 'Presse 45°', 'quadris', 'transfert', true, 'disques', 10],
  ['d-hack-squat', 'Hack squat', 'quadris', 'debout', true, 'disques', 10],
  ['d-pendulum', 'Pendulum squat', 'quadris', 'debout', true, 'disques', 5],
  ['d-belt-squat', 'Belt squat', 'quadris', 'debout', true, 'disques', 10],
  ['d-hip-thrust', 'Hip thrust à disques', 'fessiers', 'transfert', true, 'disques', 10],
  ['d-mollets', 'Mollets à disques', 'mollets', 'transfert', true, 'disques', 10],
  ['d-curl', 'Curl pupitre à disques', 'biceps', 'transfert', true, 'disques', 2.5],

  // Smith machine — guidée, mais disques
  ['s-developpe-couche', 'Développé couché Smith', 'pecs', 'transfert', true, 'smith', 5],
  ['s-developpe-incline', 'Développé incliné Smith', 'pecs', 'transfert', true, 'smith', 5],
  ['s-developpe-epaules', 'Développé épaules Smith (assis)', 'epaules', 'transfert', true, 'smith', 5],
  ['s-rowing', 'Rowing Smith', 'dos', 'debout', true, 'smith', 5],
  ['s-squat', 'Squat Smith', 'quadris', 'debout', true, 'smith', 5],

  // Haltères — depuis le fauteuil, Jules peut passer les haltères
  ['h-curl', 'Curl haltères', 'biceps', 'fauteuil', false, 'halteres', 2],
  ['h-elevation-laterale', 'Élévations latérales haltères', 'epaules', 'fauteuil', false, 'halteres', 2],
  ['h-developpe-epaules', 'Développé épaules haltères', 'epaules', 'fauteuil', true, 'halteres', 2],
]

const cardio: [id: string, name: string, posture: Posture][] = [
  ['c-tapis', 'Tapis de course / marche', 'debout'],
  ['c-tapis-incline', 'Tapis marche inclinée', 'debout'],
  ['c-escalier', 'Machine à escalier', 'debout'],
  ['c-rameur', 'Rameur', 'transfert'],
  ['c-skierg', 'SkiErg', 'debout'],
  ['c-skierg-assis', 'SkiErg assis', 'fauteuil'],
  ['c-ergo-bras', 'Ergomètre à bras', 'fauteuil'],
  ['c-velo', 'Vélo droit', 'transfert'],
  ['c-velo-allonge', 'Vélo semi-allongé', 'transfert'],
  ['c-air-bike', 'Air bike', 'transfert'],
  ['c-elliptique', 'Elliptique', 'debout'],
]

export const BASE_EXERCISES: Exercise[] = [
  ...muscu.map(([id, name, muscle, posture, help, equipment, step]) => ({
    id,
    name,
    kind: 'muscu' as Kind,
    muscle,
    posture,
    help,
    equipment,
    step,
  })),
  ...cardio.map(([id, name, posture]) => ({
    id,
    name,
    kind: 'cardio' as Kind,
    muscle: 'cardio' as Muscle,
    posture,
    help: false,
    equipment: 'cardio' as Equipment,
  })),
]

export const MUSCLE_LABEL: Record<Muscle, string> = {
  pecs: 'Pectoraux',
  dos: 'Dos',
  epaules: 'Épaules',
  biceps: 'Biceps',
  triceps: 'Triceps',
  quadris: 'Quadriceps',
  ischios: 'Ischios',
  fessiers: 'Fessiers',
  mollets: 'Mollets',
  abdos: 'Abdos',
  cardio: 'Cardio',
}

export const POSTURE_LABEL: Record<Posture, string> = {
  fauteuil: 'Depuis le fauteuil',
  transfert: 'Transfert',
  debout: 'Debout',
}

export const POSTURE_SHORT: Record<Posture, string> = {
  fauteuil: 'Fauteuil',
  transfert: 'Transfert',
  debout: 'Debout',
}

export const EQUIPMENT_LABEL: Record<Equipment, string> = {
  machine: 'Machine guidée',
  disques: 'Machine à disques',
  poulie: 'Poulie',
  smith: 'Smith machine',
  halteres: 'Haltères',
  cardio: 'Cardio',
}
