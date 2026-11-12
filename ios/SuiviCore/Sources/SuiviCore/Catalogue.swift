import Foundation

/// Catalogue de base (miroir de `appli/src/data/exercises.ts`, même ordre).
/// Marque par défaut : Hammer Strength pour les disques, Technogym pour les machines,
/// poulies et le cardio, « autre » pour le SkiErg (Concept2).
public enum Catalogue {
    public static let base: [Exercise] = [
        Exercise(id: "poulie-tirage-vertical", name: "Tirage vertical à la poulie", kind: .muscu, muscle: .dos, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-tirage-horizontal", name: "Tirage horizontal à la poulie", kind: .muscu, muscle: .dos, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-tirage-unilateral", name: "Tirage unilatéral à la poulie", kind: .muscu, muscle: .dos, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-face-pull", name: "Face pull", kind: .muscu, muscle: .epaules, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-rotation-externe", name: "Rotation externe d’épaule", kind: .muscu, muscle: .epaules, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 1.25),
        Exercise(id: "poulie-elevation-laterale", name: "Élévation latérale à la poulie", kind: .muscu, muscle: .epaules, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 1.25),
        Exercise(id: "poulie-developpe-poitrine", name: "Développé poitrine à la poulie", kind: .muscu, muscle: .pecs, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-vis-a-vis", name: "Écarté vis-à-vis", kind: .muscu, muscle: .pecs, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-curl", name: "Curl biceps à la poulie", kind: .muscu, muscle: .biceps, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-triceps", name: "Extension triceps poulie haute", kind: .muscu, muscle: .triceps, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-triceps-nuque", name: "Extension triceps au-dessus de la tête", kind: .muscu, muscle: .triceps, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-crunch", name: "Crunch à la poulie", kind: .muscu, muscle: .abdos, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "poulie-rotation-buste", name: "Rotation du buste à la poulie (woodchop)", kind: .muscu, muscle: .abdos, posture: .fauteuil, help: false, equipment: .poulie, brand: .technogym, step: 2.5),
        Exercise(id: "m-chest-press", name: "Chest press", kind: .muscu, muscle: .pecs, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-chest-press-incline", name: "Chest press inclinée", kind: .muscu, muscle: .pecs, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-pec-deck", name: "Pec deck (butterfly)", kind: .muscu, muscle: .pecs, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-shoulder-press", name: "Développé épaules machine", kind: .muscu, muscle: .epaules, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-elevation-laterale", name: "Élévations latérales machine", kind: .muscu, muscle: .epaules, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 2.5),
        Exercise(id: "m-oiseau", name: "Oiseau machine (reverse pec deck)", kind: .muscu, muscle: .epaules, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 2.5),
        Exercise(id: "m-lat-pulldown", name: "Tirage vertical machine", kind: .muscu, muscle: .dos, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-rowing", name: "Rowing assis machine", kind: .muscu, muscle: .dos, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-pullover", name: "Pull-over machine", kind: .muscu, muscle: .dos, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-tractions-assistees", name: "Tractions assistées", kind: .muscu, muscle: .dos, posture: .debout, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-lombaires", name: "Extension lombaires machine", kind: .muscu, muscle: .dos, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-curl", name: "Curl biceps machine", kind: .muscu, muscle: .biceps, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 2.5),
        Exercise(id: "m-triceps", name: "Extension triceps machine", kind: .muscu, muscle: .triceps, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 2.5),
        Exercise(id: "m-dips-assis", name: "Dips assis machine", kind: .muscu, muscle: .triceps, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-presse", name: "Presse à cuisses", kind: .muscu, muscle: .quadris, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-leg-extension", name: "Leg extension", kind: .muscu, muscle: .quadris, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-leg-curl-assis", name: "Leg curl assis", kind: .muscu, muscle: .ischios, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-leg-curl-allonge", name: "Leg curl allongé", kind: .muscu, muscle: .ischios, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-abducteurs", name: "Abducteurs machine", kind: .muscu, muscle: .fessiers, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-adducteurs", name: "Adducteurs machine", kind: .muscu, muscle: .quadris, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-hip-thrust", name: "Hip thrust machine", kind: .muscu, muscle: .fessiers, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-kickback", name: "Kickback fessiers machine", kind: .muscu, muscle: .fessiers, posture: .debout, help: false, equipment: .machine, brand: .technogym, step: 2.5),
        Exercise(id: "m-mollets-assis", name: "Mollets assis machine", kind: .muscu, muscle: .mollets, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-crunch", name: "Crunch machine", kind: .muscu, muscle: .abdos, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "m-rotation-buste", name: "Rotation du buste machine", kind: .muscu, muscle: .abdos, posture: .transfert, help: false, equipment: .machine, brand: .technogym, step: 5),
        Exercise(id: "d-chest-press", name: "Chest press convergente à disques", kind: .muscu, muscle: .pecs, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-incline-press", name: "Développé incliné à disques", kind: .muscu, muscle: .pecs, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-shoulder-press", name: "Développé épaules à disques", kind: .muscu, muscle: .epaules, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-row-isolateral", name: "Rowing iso-latéral à disques", kind: .muscu, muscle: .dos, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-lat-isolateral", name: "Tirage vertical iso-latéral à disques", kind: .muscu, muscle: .dos, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-tbar", name: "T-bar row poitrine appuyée", kind: .muscu, muscle: .dos, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-presse-45", name: "Presse 45°", kind: .muscu, muscle: .quadris, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 10),
        Exercise(id: "d-hack-squat", name: "Hack squat", kind: .muscu, muscle: .quadris, posture: .debout, help: true, equipment: .disques, brand: .hammer, step: 10),
        Exercise(id: "d-pendulum", name: "Pendulum squat", kind: .muscu, muscle: .quadris, posture: .debout, help: true, equipment: .disques, brand: .hammer, step: 5),
        Exercise(id: "d-belt-squat", name: "Belt squat", kind: .muscu, muscle: .quadris, posture: .debout, help: true, equipment: .disques, brand: .hammer, step: 10),
        Exercise(id: "d-hip-thrust", name: "Hip thrust à disques", kind: .muscu, muscle: .fessiers, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 10),
        Exercise(id: "d-mollets", name: "Mollets à disques", kind: .muscu, muscle: .mollets, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 10),
        Exercise(id: "d-curl", name: "Curl pupitre à disques", kind: .muscu, muscle: .biceps, posture: .transfert, help: true, equipment: .disques, brand: .hammer, step: 2.5),
        Exercise(id: "s-developpe-couche", name: "Développé couché Smith", kind: .muscu, muscle: .pecs, posture: .transfert, help: true, equipment: .smith, brand: nil, step: 5),
        Exercise(id: "s-developpe-incline", name: "Développé incliné Smith", kind: .muscu, muscle: .pecs, posture: .transfert, help: true, equipment: .smith, brand: nil, step: 5),
        Exercise(id: "s-developpe-epaules", name: "Développé épaules Smith (assis)", kind: .muscu, muscle: .epaules, posture: .transfert, help: true, equipment: .smith, brand: nil, step: 5),
        Exercise(id: "s-rowing", name: "Rowing Smith", kind: .muscu, muscle: .dos, posture: .debout, help: true, equipment: .smith, brand: nil, step: 5),
        Exercise(id: "s-squat", name: "Squat Smith", kind: .muscu, muscle: .quadris, posture: .debout, help: true, equipment: .smith, brand: nil, step: 5),
        Exercise(id: "h-curl", name: "Curl haltères", kind: .muscu, muscle: .biceps, posture: .fauteuil, help: false, equipment: .halteres, brand: nil, step: 2),
        Exercise(id: "h-elevation-laterale", name: "Élévations latérales haltères", kind: .muscu, muscle: .epaules, posture: .fauteuil, help: false, equipment: .halteres, brand: nil, step: 2),
        Exercise(id: "h-developpe-epaules", name: "Développé épaules haltères", kind: .muscu, muscle: .epaules, posture: .fauteuil, help: true, equipment: .halteres, brand: nil, step: 2),
        Exercise(id: "c-tapis", name: "Tapis de course / marche", kind: .cardio, muscle: .cardio, posture: .debout, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-tapis-incline", name: "Tapis marche inclinée", kind: .cardio, muscle: .cardio, posture: .debout, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-escalier", name: "Machine à escalier", kind: .cardio, muscle: .cardio, posture: .debout, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-rameur", name: "Rameur", kind: .cardio, muscle: .cardio, posture: .transfert, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-skierg", name: "SkiErg", kind: .cardio, muscle: .cardio, posture: .debout, help: false, equipment: .cardio, brand: .autre),
        Exercise(id: "c-skierg-assis", name: "SkiErg assis", kind: .cardio, muscle: .cardio, posture: .fauteuil, help: false, equipment: .cardio, brand: .autre),
        Exercise(id: "c-ergo-bras", name: "Ergomètre à bras (Technogym Top)", kind: .cardio, muscle: .cardio, posture: .fauteuil, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-velo", name: "Vélo droit", kind: .cardio, muscle: .cardio, posture: .transfert, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-velo-allonge", name: "Vélo semi-allongé", kind: .cardio, muscle: .cardio, posture: .transfert, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-air-bike", name: "Air bike", kind: .cardio, muscle: .cardio, posture: .transfert, help: false, equipment: .cardio, brand: .technogym),
        Exercise(id: "c-elliptique", name: "Elliptique", kind: .cardio, muscle: .cardio, posture: .debout, help: false, equipment: .cardio, brand: .technogym),
    ]

    public static func muscleLabel(_ m: Muscle) -> String {
        switch m {
        case .pecs: "Pectoraux"
        case .dos: "Dos"
        case .epaules: "Épaules"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .quadris: "Quadriceps"
        case .ischios: "Ischios"
        case .fessiers: "Fessiers"
        case .mollets: "Mollets"
        case .abdos: "Abdos"
        case .cardio: "Cardio"
        }
    }
}
