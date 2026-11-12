import Foundation

/// Photos « départ / arrivée » de free-exercise-db, affichées depuis GitHub (jamais copiées dans le dépôt).
public enum Illustrations {
    static let base = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    static let map: [String: (id: String, approx: Bool)] = [
        "poulie-tirage-vertical": ("Wide-Grip_Lat_Pulldown", false),
        "poulie-tirage-horizontal": ("Seated_Cable_Rows", false),
        "poulie-tirage-unilateral": ("Seated_One-arm_Cable_Pulley_Rows", false),
        "poulie-face-pull": ("Face_Pull", false),
        "poulie-rotation-externe": ("External_Rotation_with_Cable", false),
        "poulie-elevation-laterale": ("Cable_Seated_Lateral_Raise", false),
        "poulie-developpe-poitrine": ("Cable_Chest_Press", false),
        "poulie-vis-a-vis": ("Cable_Crossover", false),
        "poulie-curl": ("Standing_Biceps_Cable_Curl", false),
        "poulie-triceps": ("Triceps_Pushdown", false),
        "poulie-triceps-nuque": ("Cable_Rope_Overhead_Triceps_Extension", false),
        "poulie-crunch": ("Cable_Seated_Crunch", false),
        "poulie-rotation-buste": ("Standing_Cable_Wood_Chop", false),
        "m-chest-press": ("Machine_Bench_Press", false),
        "m-chest-press-incline": ("Leverage_Incline_Chest_Press", false),
        "m-pec-deck": ("Butterfly", false),
        "m-shoulder-press": ("Machine_Shoulder_Military_Press", false),
        "m-oiseau": ("Reverse_Machine_Flyes", false),
        "m-lat-pulldown": ("Wide-Grip_Lat_Pulldown", false),
        "m-rowing": ("Seated_Cable_Rows", true),
        "m-curl": ("Machine_Bicep_Curl", false),
        "m-triceps": ("Machine_Triceps_Extension", false),
        "m-dips-assis": ("Dip_Machine", false),
        "m-presse": ("Leg_Press", false),
        "m-leg-extension": ("Leg_Extensions", false),
        "m-leg-curl-assis": ("Seated_Leg_Curl", false),
        "m-leg-curl-allonge": ("Lying_Leg_Curls", false),
        "m-abducteurs": ("Thigh_Abductor", false),
        "m-adducteurs": ("Thigh_Adductor", false),
        "m-kickback": ("One-Legged_Cable_Kickback", true),
        "m-mollets-assis": ("Seated_Calf_Raise", false),
        "m-crunch": ("Ab_Crunch_Machine", false),
        "m-tractions-assistees": ("Band_Assisted_Pull-Up", true),
        "m-lombaires": ("Hyperextensions_Back_Extensions", true),
        "m-hip-thrust": ("Barbell_Hip_Thrust", true),
        "d-chest-press": ("Leverage_Chest_Press", false),
        "d-incline-press": ("Leverage_Incline_Chest_Press", false),
        "d-shoulder-press": ("Leverage_Shoulder_Press", false),
        "d-row-isolateral": ("Leverage_Iso_Row", false),
        "d-tbar": ("Lying_T-Bar_Row", false),
        "d-presse-45": ("Leg_Press", false),
        "d-hack-squat": ("Hack_Squat", false),
        "d-mollets": ("Calf_Press", true),
        "d-curl": ("Machine_Preacher_Curls", false),
        "d-hip-thrust": ("Barbell_Hip_Thrust", true),
        "s-developpe-couche": ("Smith_Machine_Bench_Press", false),
        "s-developpe-incline": ("Smith_Machine_Incline_Bench_Press", false),
        "s-developpe-epaules": ("Smith_Machine_Overhead_Shoulder_Press", false),
        "s-rowing": ("Smith_Machine_Bent_Over_Row", false),
        "s-squat": ("Smith_Machine_Squat", false),
        "h-curl": ("Dumbbell_Bicep_Curl", false),
        "h-elevation-laterale": ("Side_Lateral_Raise", false),
        "h-developpe-epaules": ("Seated_Dumbbell_Press", false),
        "c-tapis": ("Jogging_Treadmill", false),
        "c-tapis-incline": ("Jogging_Treadmill", true),
        "c-escalier": ("Stairmaster", false),
        "c-rameur": ("Rowing_Stationary", false),
        "c-velo": ("Bicycling_Stationary", false),
        "c-velo-allonge": ("Recumbent_Bike", false),
        "c-elliptique": ("Elliptical_Trainer", false),
    ]

    public static func urls(for exerciseId: String) -> (start: URL, end: URL)? {
        guard let m = map[exerciseId],
              let start = URL(string: "\(base)\(m.id)/0.jpg"),
              let end = URL(string: "\(base)\(m.id)/1.jpg") else { return nil }
        return (start, end)
    }

    /// Mouvement proche, pas exactement la même machine.
    public static func isApproximate(_ exerciseId: String) -> Bool {
        map[exerciseId]?.approx ?? false
    }
}
