/**
 * Illustrations des mouvements : photos « position de départ / d'arrivée » de
 * free-exercise-db (github.com/yuhonas/free-exercise-db).
 *
 * ⚠️ Licence : le projet se déclare domaine public (Unlicense), mais ses photos
 * viennent visiblement de Bodybuilding.com. On ne les copie donc PAS dans le dépôt :
 * l'appli les affiche depuis GitHub (et le téléphone les garde en cache).
 * Usage privé uniquement : à retirer si l'appli devenait publique.
 */
const BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/'

const MAP: Record<string, { id: string; approx?: boolean }> = {
  'poulie-tirage-vertical': { id: 'Wide-Grip_Lat_Pulldown' },
  'poulie-tirage-horizontal': { id: 'Seated_Cable_Rows' },
  'poulie-tirage-unilateral': { id: 'Seated_One-arm_Cable_Pulley_Rows' },
  'poulie-face-pull': { id: 'Face_Pull' },
  'poulie-rotation-externe': { id: 'External_Rotation_with_Cable' },
  'poulie-elevation-laterale': { id: 'Cable_Seated_Lateral_Raise' },
  'poulie-developpe-poitrine': { id: 'Cable_Chest_Press' },
  'poulie-vis-a-vis': { id: 'Cable_Crossover' },
  'poulie-curl': { id: 'Standing_Biceps_Cable_Curl' },
  'poulie-triceps': { id: 'Triceps_Pushdown' },
  'poulie-triceps-nuque': { id: 'Cable_Rope_Overhead_Triceps_Extension' },
  'poulie-crunch': { id: 'Cable_Seated_Crunch' },
  'poulie-rotation-buste': { id: 'Standing_Cable_Wood_Chop' },
  'm-chest-press': { id: 'Machine_Bench_Press' },
  'm-chest-press-incline': { id: 'Leverage_Incline_Chest_Press' },
  'm-pec-deck': { id: 'Butterfly' },
  'm-shoulder-press': { id: 'Machine_Shoulder_Military_Press' },
  'm-oiseau': { id: 'Reverse_Machine_Flyes' },
  'm-lat-pulldown': { id: 'Wide-Grip_Lat_Pulldown' },
  'm-rowing': { id: 'Seated_Cable_Rows', approx: true },
  'm-curl': { id: 'Machine_Bicep_Curl' },
  'm-triceps': { id: 'Machine_Triceps_Extension' },
  'm-dips-assis': { id: 'Dip_Machine' },
  'm-presse': { id: 'Leg_Press' },
  'm-leg-extension': { id: 'Leg_Extensions' },
  'm-leg-curl-assis': { id: 'Seated_Leg_Curl' },
  'm-leg-curl-allonge': { id: 'Lying_Leg_Curls' },
  'm-abducteurs': { id: 'Thigh_Abductor' },
  'm-adducteurs': { id: 'Thigh_Adductor' },
  'm-kickback': { id: 'One-Legged_Cable_Kickback', approx: true },
  'm-mollets-assis': { id: 'Seated_Calf_Raise' },
  'm-crunch': { id: 'Ab_Crunch_Machine' },
  'm-tractions-assistees': { id: 'Band_Assisted_Pull-Up', approx: true },
  'm-lombaires': { id: 'Hyperextensions_Back_Extensions', approx: true },
  'm-hip-thrust': { id: 'Barbell_Hip_Thrust', approx: true },
  'd-chest-press': { id: 'Leverage_Chest_Press' },
  'd-incline-press': { id: 'Leverage_Incline_Chest_Press' },
  'd-shoulder-press': { id: 'Leverage_Shoulder_Press' },
  'd-row-isolateral': { id: 'Leverage_Iso_Row' },
  'd-tbar': { id: 'Lying_T-Bar_Row' },
  'd-presse-45': { id: 'Leg_Press' },
  'd-hack-squat': { id: 'Hack_Squat' },
  'd-mollets': { id: 'Calf_Press', approx: true },
  'd-curl': { id: 'Machine_Preacher_Curls' },
  'd-hip-thrust': { id: 'Barbell_Hip_Thrust', approx: true },
  's-developpe-couche': { id: 'Smith_Machine_Bench_Press' },
  's-developpe-incline': { id: 'Smith_Machine_Incline_Bench_Press' },
  's-developpe-epaules': { id: 'Smith_Machine_Overhead_Shoulder_Press' },
  's-rowing': { id: 'Smith_Machine_Bent_Over_Row' },
  's-squat': { id: 'Smith_Machine_Squat' },
  'h-curl': { id: 'Dumbbell_Bicep_Curl' },
  'h-elevation-laterale': { id: 'Side_Lateral_Raise' },
  'h-developpe-epaules': { id: 'Seated_Dumbbell_Press' },
  'c-tapis': { id: 'Jogging_Treadmill' },
  'c-tapis-incline': { id: 'Jogging_Treadmill', approx: true },
  'c-escalier': { id: 'Stairmaster' },
  'c-rameur': { id: 'Rowing_Stationary' },
  'c-velo': { id: 'Bicycling_Stationary' },
  'c-velo-allonge': { id: 'Recumbent_Bike' },
  'c-elliptique': { id: 'Elliptical_Trainer' },
}

export interface Illustration {
  frames: [string, string]
  /** Mouvement proche, pas exactement la même machine. */
  approx: boolean
}

export function illustrationFor(exerciseId: string): Illustration | null {
  const m = MAP[exerciseId]
  if (!m) return null
  return { frames: [`${BASE}${m.id}/0.jpg`, `${BASE}${m.id}/1.jpg`], approx: !!m.approx }
}

export const ILLUSTRATION_CREDIT = 'Illustrations : free-exercise-db (photos d’origine Bodybuilding.com)'
