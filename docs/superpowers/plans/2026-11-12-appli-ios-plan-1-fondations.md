# Suivi Muscu iOS, plan 1 : les fondations et la séance

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objectif :** une première appli SwiftUI installée sur l'iPhone 14 de Clément. Elle s'ouvre sur le tableau de bord B (animé), permet de faire une séance complète avec la pyramide 12/10/8/12, et garde tout sur le téléphone.

**Architecture :** la logique métier vit dans un paquet Swift `SuiviCore`, sans interface : modèles, catalogue, règles, statistiques, stockage. On la teste avec `swift test` sur le Mac, sans simulateur. L'appli `SuiviMuscu` (SwiftUI, iOS 18) ne contient que des vues et un `AppStore` observable fourni par le cœur. Le projet Xcode est généré par XcodeGen à partir d'un `project.yml`, pour rester lisible et versionnable.

**Technologies :** Swift 6.4, SwiftUI, Observation, Swift Testing, XcodeGen (Homebrew), Xcode 27.2, iOS 18 minimum.

**Brief :** `docs/superpowers/specs/2026-11-12-appli-ios-swiftui-design.md` (à lire avant de commencer). L'appli web de référence est dans `appli/src/`.

## Découpage du projet en 4 plans

Le brief couvre plusieurs sous-systèmes indépendants. Chacun aura son plan, et chaque plan livre une appli qui marche :

1. **Ce plan** : projet, cœur métier, stockage local, tableau de bord B, séance en direct avec pyramide et minuteur, réglages essentiels, installation sur l'iPhone de Clément.
2. **Plan 2** : Planning et préparation de séance, tableau de charge (Swift Charts animé), catalogue Machines (édition, photos, illustrations), sauvegarde et import.
3. **Plan 3** : les icônes maison dans VectorCraft et l'icône de l'appli. Elles remplacent les SF Symbols provisoires grâce à l'énumération `AppIcon` (tâche 6).
4. **Plan 4** : synchro Supabase, connexion, tâche planifiée qui garde la base éveillée, TestFlight pour Jules.

## Contraintes globales

- iOS 18.0 minimum ; iPhone uniquement ; orientation portrait.
- Identifiant de l'appli : `fr.suivimuscu.app` ; nom affiché : « Suivi Muscu ».
- Tout le texte visible est en français (copie du web quand l'écran existe déjà).
- Le JSON stocké garde **les mêmes noms de champs que le web** (`appli/src/lib/types.ts`), pour que la synchro du plan 4 lise les mêmes données. Les nouveaux champs sont optionnels.
- Couleurs reprises de `appli/src/styles.css` : fond dégradé `#64746f` → `#46534f`, verre `#ECF1EF` à 84 %, encre `#17201D`, profil 1 (Clément) `#00806A`, profil 2 (Jules) `#D65A1F`, succès `#0CA30C`. Coins arrondis 26 pt (cartes) et 18 pt (petits blocs). Zone tactile minimale 48 pt.
- Police : la police système en version arrondie (`.rounded`). C'est un choix de Claude, à la place de Poppins.
- Animations : 350 ms au plus, jamais bloquantes (un bouton reste utilisable pendant une animation). Si `accessibilityReduceMotion` est actif, on remplace les mouvements par des fondus.
- Retour haptique avec `.sensoryFeedback` : `.success` pour une série validée, `.impact(weight: .heavy)` pour un record, `.warning` pour la fin du repos.
- Les icônes passent toutes par `AppIcon` (tâche 6) : aucun `Image(systemName:)` en dehors de ce fichier.
- Aucune comparaison de charges entre Clément et Jules.

## Points de vigilance

Les situations qui risquent le plus de gêner à la salle, et le test qui les couvre :

1. **Appli tuée en pleine séance** (batterie, mise à jour) : en la rouvrant, on retrouve la séance et les séries cochées. → test `reloadKeepsLiveSession`, tâche 5.
2. **Série 4 déjà validée, puis on change la série 1** : la série 4 ne doit plus bouger (une série faite ne change jamais toute seule). → test `pyramidDoesNotTouchDoneSet4`, tâche 3.
3. **Séance oubliée sans « Terminer »** : elle ne doit pas gonfler les heures de la semaine. → test `unfinishedSessionCappedAt150`, tâche 4.
4. **Séance du dimanche soir** : elle compte dans la semaine qui finit ce dimanche, pas dans la suivante. → test `sundayBelongsToPreviousMonday`, tâche 4.
5. **Passer un exercice de pyramide à classique en pleine séance** : les séries déjà faites restent intactes. → test `switchingSchemeKeepsDoneSets`, tâche 3.

---

## Arborescence

```
ios/
  project.yml                       XcodeGen : cible SuiviMuscu + dépendance au paquet local
  SuiviCore/                        paquet Swift (logique, testé par `swift test`)
    Package.swift
    Sources/SuiviCore/
      Model.swift                   types Codable (miroir de types.ts) + nouveaux champs
      Catalogue.swift               les 70 exercices, libellés de muscles, marques
      Illustrations.swift           exerciseId -> images free-exercise-db
      Dates.swift                   isoDate, weekStart (lundi), addDays : en heure de Paris
      Rules.swift                   pyramide/classique, nouvel item, aide, titres
      Stats.swift                   durées, semaine, ensemble, dernière perf, records
      AppStore.swift                état observable + persistance JSON
      DemoData.swift                données de démo (même contenu que celles de la maquette)
    Tests/SuiviCoreTests/
      ModelTests.swift  CatalogueTests.swift  RulesTests.swift  StatsTests.swift  StoreTests.swift
  SuiviMuscu/                       l'appli
    SuiviMuscuApp.swift  RootView.swift
    Design/   Theme.swift  AppIcon.swift  Glass.swift  Motion.swift
    Home/     HomeView.swift  WeekRingCard.swift  TogetherCard.swift  NextSessionCard.swift  SessionFeed.swift
    Session/  SessionView.swift  ExerciseCard.swift  SetRow.swift  Stepper.swift  RestTimer.swift
              ExercisePicker.swift  FinishSheet.swift  RecordBurst.swift
    Settings/ SettingsView.swift  AvatarPicker.swift
    Resources/Assets.xcassets       couleurs, logo KOMEX (SVG, données vectorielles conservées)
```

---

### Tâche 1 : projet Xcode et paquet SuiviCore qui compilent

**Fichiers :**
- Créer : `ios/project.yml`, `ios/SuiviCore/Package.swift`, `ios/SuiviCore/Sources/SuiviCore/SuiviCore.swift` (vide pour l'instant), `ios/SuiviCore/Tests/SuiviCoreTests/SmokeTests.swift`, `ios/SuiviMuscu/SuiviMuscuApp.swift`, `ios/SuiviMuscu/Resources/Assets.xcassets`, `ios/.gitignore`
- Copier : `../.superpowers/brainstorm/*/content/logo-komex.svg` → `ios/SuiviMuscu/Resources/Assets.xcassets/KomexLogo.imageset/logo-komex.svg` (rendu « original », données vectorielles conservées)

**Interfaces :**
- Produit : la cible `SuiviMuscu` (bundle `fr.suivimuscu.app`, iOS 18) qui dépend du produit `SuiviCore`. Le paquet `SuiviCore` déclare les plateformes `.iOS(.v18)` et `.macOS(.v15)`, pour que `swift test` tourne sur le Mac.

- [ ] **Étape 1 : installer XcodeGen** — `brew install xcodegen`. Attendu : `xcodegen --version` affiche une version.
- [ ] **Étape 2 : écrire le test minimal** `SmokeTests.swift` : `@Test func coreLoads() { #expect(SuiviCore.version == "1") }`.
- [ ] **Étape 3 : le lancer** — `cd ios/SuiviCore && swift test`. Attendu : échec (`version` n'existe pas).
- [ ] **Étape 4 : ajouter** `public enum SuiviCore { public static let version = "1" }`, puis `project.yml`. L'appli affiche « Suivi Muscu » sur le fond dégradé. `DEVELOPMENT_TEAM` est laissé vide ici (tâche 10).
- [ ] **Étape 5 : vérifier** — `swift test` passe. Puis `cd ios && xcodegen && xcodebuild -project SuiviMuscu.xcodeproj -scheme SuiviMuscu -destination 'platform=iOS Simulator,name=iPhone 17' build` : attendu `BUILD SUCCEEDED`.
- [ ] **Étape 6 : commit** — `git add ios && git commit -m "ios: projet XcodeGen et paquet SuiviCore"`. `SuiviMuscu.xcodeproj` est généré, donc ignoré par `ios/.gitignore`.

### Tâche 2 : les modèles et le catalogue

**Fichiers :**
- Créer : `Model.swift`, `Catalogue.swift`, `Illustrations.swift`, `Dates.swift`
- Tests : `ModelTests.swift`, `CatalogueTests.swift`

**Interfaces :**
- Produit :
  - **Énumérations** (valeurs brutes = celles de `types.ts`) : `Kind`, `Posture`, `Muscle`, `Equipment`, `Brand`, `SessionStatus`, et la nouvelle `RepScheme { case pyramid, classic }`.
  - **Structures** `Codable, Hashable, Identifiable` avec les champs de `types.ts` :
    - `Exercise`, `Profile`, `SetEntry`, `CardioEntry`, `SessionItem`, `Session` ;
    - `SessionItem` gagne `scheme: RepScheme?` ;
    - `Profile` gagne `settings: ProfileSettings?`, avec `ProfileSettings { weeklyGoal: Int?; defaultScheme: RepScheme? }`.
  - **Le catalogue** :
    - `Catalogue.base: [Exercise]` (les 70 de `appli/src/data/exercises.ts`, même ordre, mêmes marques par défaut via `defaultBrand`) ;
    - `Catalogue.muscleLabel(_ m: Muscle) -> String`.
  - **Les illustrations** : `Illustrations.urls(for exerciseId: String) -> (start: URL, end: URL)?`, reprise de `appli/src/data/illustrations.ts`.
  - **Les dates** : `Dates.isoDate(_ d: Date) -> String`, `Dates.weekStart(_ iso: String) -> String` (lundi), `Dates.addDays(_ iso: String, _ n: Int) -> String`. Toutes en fuseau `Europe/Paris`.

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `decodesWebSessionJSON` : décode une `Session` écrite au format du web, et le réencodage redonne les mêmes clés. Le JSON est en dur dans le test : 1 item de 2 séries, `startedAt`, `endedAt`, `durationMin: 55`.
  - `catalogueHas70` : `#expect(Catalogue.base.count == 70)` et `#expect(Catalogue.base.filter { $0.kind == .cardio }.count == 11)`.
  - `catalogueSpotChecks` :
    - `m-chest-press` → posture `.transfert`, step 5, marque `.technogym` ;
    - `d-presse-45` → help vrai, marque `.hammer` ;
    - `c-skierg` → marque `.autre` ;
    - `poulie-rotation-externe` → step 1.25.
  - `weekStartIsMonday` : `weekStart("2026-11-15") == "2026-11-09"` et `weekStart("2026-11-16") == "2026-11-16"`.
- [ ] **Étape 2 : les lancer** — `swift test`. Attendu : échec de compilation.
- [ ] **Étape 3 : implémenter** les fichiers. Le catalogue se recopie depuis `exercises.ts`, ligne à ligne.
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent.
- [ ] **Étape 5 : commit** — `git commit -m "core: modèles, catalogue des 70 exercices, dates"`.

### Tâche 3 : les règles de séance, dont la pyramide

**Fichiers :** créer `Rules.swift` et `Stats.swift` (seulement `lastPerformance`) ; tests dans `RulesTests.swift`

**Interfaces :**
- Consomme : modèles et catalogue (tâche 2).
- Produit :
  - `Stats.lastPerformance(_ sessions: [Session], ownerId: String, exerciseId: String, excluding: String?) -> (session: Session, item: SessionItem)?`, comme sur le web : la plus récente d'abord. Il vit dans `Stats.swift`, créé dans cette tâche et complété en tâche 4.
  - `RepScheme.pyramid.reps == [12, 10, 8, 12]`
  - `Rules.newItem(_ ex: Exercise, ownerId: String, sessions: [Session], scheme: RepScheme) -> SessionItem`
  - `Rules.setKg(_ item: SessionItem, index: Int, kg: Double) -> SessionItem`
  - `Rules.setReps(_ item: SessionItem, index: Int, reps: Int) -> SessionItem`
  - `Rules.switchScheme(_ item: SessionItem, to: RepScheme) -> SessionItem`
  - `Rules.defaultScheme(for p: Profile) -> RepScheme`. Par défaut : `.pyramid` pour le profil 1, `.classic` pour le profil 2.
  - `Rules.needsHelp`, `Rules.helperName`, `Rules.titleSuggestion`, `Rules.isLive`, `Rules.hasProgress`, reprises de `appli/src/lib/sessions.ts`.

**Règles :**
- **Pyramide, nouvel item.**
  - Toujours 4 séries, avec les répétitions 12/10/8/12.
  - Charges : celles de la dernière fois, série par série, si cette dernière fois était en pyramide (4 séries faites). Sinon, les 4 séries à 0 kg.
- **Pyramide, changer une charge.** Changer la série 1 copie aussi la charge dans la série 4, *si la série 4 n'est pas faite*. Changer les séries 2, 3 ou 4 ne touche qu'elles-mêmes.
- **Pyramide, changer des répétitions.** Ne copie jamais rien.
- **Classique.** Comportement du web : la dernière fois sinon 3×10 à 0 kg. Changer une charge ou des répétitions recopie la valeur dans les séries suivantes *pas encore faites*.
- **Cardio.** `scheme` vaut nil, et le comportement est celui du web.
- **Changer de schéma.** Les séries faites sont gardées telles quelles.
  - Vers la pyramide : on complète ou on tronque *les séries non faites* pour arriver à 4, et les répétitions non faites prennent 12/10/8/12 selon leur rang.
  - Vers le classique : les séries non faites prennent les répétitions et la charge de la dernière série faite, ou de la série 1.

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `pyramidNewItemWithoutHistory` : reps `[12,10,8,12]`, kg `[0,0,0,0]`.
  - `pyramidNewItemFromLastTime` : la dernière séance faite en `20/25/30/20` donne kg `[20,25,30,20]`.
  - `pyramidSet1MirrorsSet4` : `setKg(index: 0, kg: 22.5)` donne kg[0] = kg[3] = 22.5, sans toucher kg[1] ni kg[2].
  - `pyramidDoesNotTouchDoneSet4` : série 4 faite à 20, puis `setKg(index: 0, kg: 25)`, et kg[3] reste 20.
  - `classicCopiesToFollowingUndone` : 3 séries dont la 2e est faite ; `setKg(index: 0, kg: 40)` donne kg `[40, ancienne, 40]`.
  - `switchingSchemeKeepsDoneSets` : pyramide avec les séries 1 et 2 faites, passée en classique : les séries 1 et 2 sont identiques avant et après.
  - `helperLabelIsSameOnBothPhones` : avec le profil 1 qui a besoin d'aide, `helperName == "Jules"`, quel que soit le profil actif.
- [ ] **Étape 2 : les lancer** — `swift test --filter RulesTests`. Attendu : échec.
- [ ] **Étape 3 : implémenter** `Rules.swift`.
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent.
- [ ] **Étape 5 : commit** — `git commit -m "core: règles de séance et pyramide 12/10/8/12"`.

### Tâche 4 : les statistiques du tableau de bord

**Fichiers :** compléter `Stats.swift` ; tests dans `StatsTests.swift`

**Interfaces :**
- Produit :
  - `Stats.durationMinutes(_ s: Session, now: Date) -> Int`
  - `Stats.counts(_ s: Session) -> Bool` : au moins une série ou un cardio validé.
  - `Stats.week(_ sessions: [Session], ownerId: String, containing iso: String, now: Date) -> WeekSummary`, avec `WeekSummary { sessions: Int; minutes: Int; goal: Int }`. Le `goal` vient du profil, sinon 3.
  - `Stats.together(_ sessions: [Session], a: String, b: String, containing iso: String, now: Date) -> (days: Int, minutes: Int)`
  - `Stats.e1rm`, `Stats.sessionPRs(_ all: [Session], _ s: Session) -> [String]`, `Stats.sessionTonnage`, repris de `appli/src/lib/stats.ts`.
  - `Stats.formatHours(_ minutes: Int) -> String` : 165 → `"2h45"`, 60 → `"1h"`, 45 → `"45 min"`.

**Règles de durée (brief §6) :**
- Si `durationMin` est renseigné : `min(durationMin, 240)`.
- Sinon, si `startedAt` existe : de `startedAt` à `endedAt`, ou à défaut `updatedAt`. Plafond 150 minutes, et jamais négatif.
- Sinon : 0.
- Une séance qui ne compte pas (`counts == false`) vaut 0 minute et 0 séance.
- Les séances `planned` ne comptent pas, sauf si elles ont des séries faites. Côté web, une séance commencée passe à `done`.

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `typedDurationWins` : `durationMin: 70`, avec début et fin espacés de 2 h → 70.
  - `typedDurationCapped` : `durationMin: 300` → 240.
  - `unfinishedSessionCappedAt150` : début à 18:00, pas de fin, `updatedAt` le lendemain à 08:00 → 150.
  - `sundayBelongsToPreviousMonday` : une séance le `"2026-11-15"` compte dans `week(containing: "2026-11-12")` et pas dans `week(containing: "2026-11-16")`.
  - `weekSumsSessionsAndMinutes` : trois séances de 55, 50 et 60 min dans la semaine → `sessions == 3`, `minutes == 165`, `formatHours == "2h45"`.
  - `togetherCountsSharedDays` : Clément lundi et jeudi, Jules mercredi et jeudi → `days == 1`, minutes = somme des deux séances du jeudi.
  - `goalDefaultsTo3` : profil sans réglages → `goal == 3`.
- [ ] **Étape 2 : les lancer** — `swift test --filter StatsTests`. Attendu : échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent.
- [ ] **Étape 5 : commit** — `git commit -m "core: statistiques de la semaine et règles de durée"`.

### Tâche 5 : le stockage local

**Fichiers :** créer `AppStore.swift`, `DemoData.swift` ; tests dans `StoreTests.swift`

**Interfaces :**
- Produit : `@Observable @MainActor public final class AppStore`
  - `init(fileURL: URL)` : lit le fichier s'il existe. Sinon, il crée les deux profils locaux, `local-clement` (Clément, slot 1) et `local-jules` (Jules, slot 2). `meId` vaut `local-clement` par défaut.
  - Propriétés : `profiles: [Profile]`, `sessions: [Session]` (triées du plus récent au plus ancien, comme le web), `exercises: [Exercise]` (catalogue fusionné avec les corrections), `exerciseById: [String: Exercise]`, `meId: String`, `me: Profile`, `partner: Profile`.
  - Méthodes :
    - `saveSession(_:)`, `deleteSession(id:)` (suppression douce : `deleted = true`) ;
    - `saveExercise(_:)` (corrections du catalogue) ;
    - `saveProfile(_:)`, `switchProfile(to:)` ;
    - `startOrResume(sessionId:)` : pose `startedAt` à la première série cochée et passe la séance à `.done`.
  - Chaque modification écrit le fichier tout de suite, de façon atomique (`Data.write(options: .atomic)`). Format : `{ profiles, sessions, exercises, meId }` en JSON, mêmes clés que le cache web.
  - `DemoData.cache(today: String) -> (profiles, sessions, exercises)` : reprend le contenu des données de démo de la maquette, soit 4 semaines, une séance à deux prévue demain et « Bras + cardio » dimanche. On le charge si l'appli est lancée avec l'argument `-demo`.

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `freshStoreHasTwoProfiles` : dossier temporaire vide, 2 profils, `meId == "local-clement"`.
  - `reloadKeepsLiveSession` : on enregistre une séance avec 2 séries cochées, puis on crée un nouvel `AppStore` sur le même fichier : la séance et les séries cochées sont là.
  - `deletedSessionsAreHidden` : après `deleteSession`, la séance n'est plus dans `sessions`, mais toujours dans le fichier.
  - `exerciseOverrideMerges` : `saveExercise` d'une note de réglage sur `m-chest-press` → `exerciseById["m-chest-press"].note` mis à jour, sans perdre le reste.
- [ ] **Étape 2 : les lancer** — attendu : échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent.
- [ ] **Étape 5 : commit** — `git commit -m "core: stockage local et données de démo"`.

### Tâche 6 : l'habillage de l'appli (thème, icônes, verre, animations)

**Fichiers :** créer `Design/Theme.swift`, `Design/AppIcon.swift`, `Design/Glass.swift`, `Design/Motion.swift`, `RootView.swift` ; modifier `SuiviMuscuApp.swift`

**Interfaces :**
- Produit :
  - `Theme` : couleurs des contraintes globales, `Theme.color(for profile: Profile) -> Color` (slot 1 vert, slot 2 orange), `Theme.background` (le dégradé).
  - `enum AppIcon: String, CaseIterable` avec les cas `home, planning, add, load, machines, settings, sessions, time, timer, trophy, goal, together, wheelchair, transfer, standing, help, plate, cardio, sync, offline, photo, pyramid`. `var image: Image` renvoie pour l'instant un SF Symbol provisoire. Le plan 3 remplacera ces images par les icônes maison.
  - `View.glassCard()` : le fond de carte en verre, coins de 26 pt.
  - `Motion.spring` (`.spring(duration: 0.35, bounce: 0.2)`), `Motion.stagger(_ i: Int) -> Animation` (décalage de 0,06 s par rang), et `View.motion(_ animation: Animation, value:)`, qui bascule sur `.easeInOut(duration: 0.2)` sans mouvement si « Réduire les animations » est actif.
  - `RootView` : 5 onglets dans une barre flottante en verre, comme sur le web : Accueil, Planning, « + » (séance libre), Charge, Machines. Planning, Charge et Machines affichent « Bientôt » jusqu'au plan 2. L'icône de l'onglet choisi rebondit (`symbolEffect(.bounce)`).
  - `SuiviMuscuApp` crée l'`AppStore` sur `Application Support/suivi.json` et l'injecte avec `.environment`.

- [ ] **Étape 1 : implémenter** les fichiers.
- [ ] **Étape 2 : vérifier sur simulateur.** Lancer l'appli sur l'iPhone 17 avec `-demo` et faire une capture. Attendu : le fond dégradé, la barre d'onglets en bas, l'onglet Accueil actif. Faire une capture aussi avec « Réduire les animations » activé dans les réglages d'accessibilité du simulateur : l'onglet change sans rebond.
- [ ] **Étape 3 : commit** — `git commit -m "app: thème, icônes provisoires, barre d'onglets"`.

### Tâche 7 : le tableau de bord B

**Fichiers :** créer `Home/HomeView.swift`, `WeekRingCard.swift`, `TogetherCard.swift`, `NextSessionCard.swift`, `SessionFeed.swift`

**Interfaces :**
- Consomme : `Stats.week`, `Stats.together`, `Stats.formatHours`, `Stats.sessionPRs` (tâche 4), `AppStore` (tâche 5), `Theme`, `AppIcon`, `Motion` (tâche 6).
- Produit :
  - `WeekRingCard(profile: Profile, summary: WeekSummary, isMe: Bool, appearDelay: Int)`
  - `TogetherCard(days: Int, minutes: Int)`
  - `NextSessionCard(session: Session?, onOpen: () -> Void, onFree: () -> Void)`
  - `SessionFeed(sessions: [Session])`

**Ce qu'on voit (brief §6, maquette `dashboard-v3.html` option B) :**
- **En-tête :** le logo `KomexLogo` à gauche (26 pt de haut), à droite l'avatar du profil actif (photo ou initiale sur la couleur du profil), qui ouvre les Réglages. En dessous : « Cette semaine », et « Du 9 au 15 nov. » formaté en français.
- **Deux cartes** : moi à gauche, l'autre à droite. Chaque carte affiche :
  - le prénom et sa pastille de couleur ;
  - un anneau `séances / objectif`, avec « 3 » en gros et « sur 4 » en petit au centre ;
  - en dessous, `AppIcon.time` et « 2h45 ».
  - Quand l'objectif est atteint, l'anneau passe en vert succès.
- **Carte « Ensemble »** (`AppIcon.together`) : « 2 séances faites à deux · 4h35 au total ». Au singulier « 1 séance faite à deux ». À zéro : « Pas encore de séance à deux cette semaine ».
- **Carte « Prochaine séance »** : la prochaine séance prévue du profil actif (aujourd'hui ou plus tard), avec un bouton rond « lecture » orange. Sans séance prévue : « Aucune séance prévue » et un bouton « Séance libre ». Une séance en cours de l'autre (`Rules.isLive`) s'affiche au-dessus avec la pastille « En cours », comme sur le web.
- **Fil des dernières séances**, comme le web : prénom, date, titre, exercices, et les pastilles séries, tonnage, ressenti, « avec aide », records.

**Animations (brief §8) :**
- Les anneaux se remplissent de 0 à leur valeur, avec `Motion.spring` et un décalage par carte (`appearDelay`). Ça se rejoue à chaque retour sur l'Accueil.
- Les chiffres utilisent `contentTransition(.numericText())`.
- Objectif atteint : une pulsation de l'anneau (`phaseAnimator`, échelle 1 → 1,06 → 1) et `.sensoryFeedback(.success)`, une seule fois par semaine et par personne. On mémorise la semaine déjà fêtée dans `UserDefaults`.

- [ ] **Étape 1 : implémenter** les vues.
- [ ] **Étape 2 : vérifier sur simulateur** avec `-demo`. Capture de l'Accueil comme Clément, puis comme Jules (via `switchProfile`).
  - Attendu : les chiffres correspondent aux données de démo, Clément est à gauche chez lui et Jules à gauche chez lui.
  - Comparer avec `dashboard-v3.html`, option B : même ordre, mêmes contenus.
- [ ] **Étape 3 : commit** — `git commit -m "app: tableau de bord de la semaine (option B) animé"`.

### Tâche 8 : la séance en direct

**Fichiers :** créer `Session/SessionView.swift`, `ExerciseCard.swift`, `SetRow.swift`, `Stepper.swift`, `FinishSheet.swift`, `RecordBurst.swift`

**Interfaces :**
- Consomme : `Rules.setKg`, `setReps`, `switchScheme`, `newItem` (tâche 3), `Stats.lastPerformance`, `Stats.sessionPRs` (tâche 4), `AppStore.saveSession`, `startOrResume` (tâche 5).
- Produit :
  - `SessionView(sessionId: String)`
  - `Stepper(label: String, unit: String, step: Double, value: Binding<Double>)`. Il ne descend jamais sous 0 et garde un libellé d'accessibilité du type « Série 1 charge ».

**Ce qu'on voit (reprendre `appli/src/pages/SessionPage.tsx`) :**
- **En-tête :** retour, titre, profil et date, pastille « En cours », menu d'options.
- **Une carte par exercice :**
  - la vignette (illustration de départ, chargée avec `AsyncImage` et mise en cache par `URLCache`) ;
  - le nom et les badges Fauteuil / Transfert / Debout / « Aide Jules » ;
  - la note de réglage dans un bandeau ;
  - « Dernière fois (6 nov.) : 20×12 · 25×10 · 30×8 · 20×12 » ;
  - un sélecteur compact « Pyramide / Classique » qui appelle `switchScheme`.
- **Chaque série :** son numéro, deux `Stepper` (kg avec le pas de l'exercice, 2,5 par défaut ; reps de 1 en 1), et un bouton de validation rond de 56 pt, plein, avec une coche visible même avant validation.
- **En bas :** « + Série », « Retirer la dernière », et la barre fixe avec le minuteur (tâche 9) et « Terminer ».
- **« Terminer »** ouvre `FinishSheet` : la durée, préremplie avec `Stats.durationMinutes` et modifiable de 5 en 5, et le ressenti (facultatif). Valider renseigne `endedAt` et `durationMin`.
- **L'écran reste allumé** tant que la séance est ouverte et commencée (`UIApplication.shared.isIdleTimerDisabled`). On le remet à `false` en quittant l'écran.

**Animations :**
- Valider une série : la coche rebondit (`symbolEffect(.bounce)`), la ligne passe au vert (`Motion.spring`), et `.sensoryFeedback(.success)`.
- Un chiffre qui change défile (`contentTransition(.numericText())`).
- Record battu à la validation (`sessionPRs` contient cet exercice pour la première fois) : `RecordBurst`, un trophée qui grossit avec 8 particules sur 0,6 s, en superposition et sans bloquer les boutons. Plus `.sensoryFeedback(.impact(weight: .heavy))`, une seule fois par exercice et par séance.
- Passage de la carte du fil ou de « Prochaine séance » à la séance : `matchedTransitionSource` puis `.navigationTransition(.zoom)`, disponibles en iOS 18.

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur** avec `-demo`. Ouvrir « Séance à deux » comme Clément.
  - Changer la série 1 à 45 kg : la série 4 suit, les séries 2 et 3 ne bougent pas.
  - Valider les séries 1 à 4.
  - Changer à nouveau la série 1 : la série 4, déjà faite, ne bouge pas.
  - Capture avant et après.
  - Tuer l'appli (`xcrun simctl terminate`) et la relancer : les séries cochées sont toujours là.
- [ ] **Étape 3 : commit** — `git commit -m "app: séance en direct avec pyramide, validation animée et records"`.

### Tâche 9 : le minuteur de repos et l'ajout d'exercices

**Fichiers :** créer `Session/RestTimer.swift`, `Session/ExercisePicker.swift` ; modifier `SessionView.swift`

**Interfaces :**
- Produit :
  - `RestTimer` (vue et modèle `@Observable final class RestTimerModel { start(seconds: Int); add(_ s: Int); stop(); remaining: Int }`) ;
  - `ExercisePicker(onAdd: ([Exercise]) -> Void)`.

**Minuteur :**
- Il démarre à chaque série validée. Durée : 90 s par défaut, réglable en tâche 10.
- Il s'affiche comme un anneau qui se vide, avec le temps restant, et les boutons « +30 » et « × ».
- Sur les 3 dernières secondes : une pulsation par seconde.
- À zéro : `.sensoryFeedback(.warning)` et un son système court.
- En arrière-plan, une notification locale est programmée pour la fin du repos (`UNUserNotificationCenter`, autorisation demandée à la première séance) et annulée si on revient avant.
- Il se base sur l'heure de fin et non sur un décompte, pour rester juste après un passage en arrière-plan.

**Sélecteur d'exercices :**
- Une recherche et des filtres Posture (Depuis le fauteuil / Transfert / Debout), Aide et Muscle.
- Le filtre de posture choisi est retenu (`@AppStorage("picker.posture")`).
- La sélection est multiple, avec le bouton « Ajouter (n) ».
- Chaque exercice ajouté passe par `Rules.newItem`, avec le schéma par défaut du profil.

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur.**
  - Valider une série : le minuteur apparaît et descend.
  - « +30 » ajoute bien 30 s.
  - Passer l'appli en arrière-plan 10 s avec un minuteur réglé à 15 s : une notification arrive.
  - Ajouter « Chest press » comme Clément : 4 séries 12/10/8/12.
  - Fermer et rouvrir le sélecteur : le filtre fauteuil est toujours actif.
- [ ] **Étape 3 : commit** — `git commit -m "app: minuteur de repos et sélecteur d'exercices"`.

### Tâche 10 : les réglages essentiels et l'installation sur l'iPhone de Clément

**Fichiers :** créer `Settings/SettingsView.swift`, `Settings/AvatarPicker.swift` ; modifier `ios/project.yml`

**Interfaces :**
- Consomme : `AppStore.saveProfile`, `switchProfile` (tâche 5).

**Réglages :**
- « Profil actif » : Clément / Jules. C'est le mode local, où les deux sont sur le même téléphone, comme sur le web.
- Pour chaque profil :
  - la photo (`PhotosPicker`, recadrée en carré au centre légèrement au-dessus, comme `appli/src/lib/image.ts`, JPEG d'environ 20 Ko stocké en data URL dans `avatar`) ;
  - « A besoin d'aide pour les disques » ;
  - l'objectif de séances par semaine (1 à 7, 3 par défaut) ;
  - le schéma par défaut, Pyramide 12/10/8/12 ou Classique.
- Réglage de séance : la durée du repos, de 30 à 180 s par pas de 15, 90 par défaut.
- « Ma salle » : KOMEX, 64B rue Sully, Dijon, avec un lien Plans.

**Installation :**
- `DEVELOPMENT_TEAM` = l'identifiant d'équipe du certificat « Apple Development » du Mac. On le lit avec `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject` : c'est le champ `OU`.
- La signature est automatique (`CODE_SIGN_STYLE: Automatic`).

- [ ] **Étape 1 : implémenter** les réglages.
- [ ] **Étape 2 : vérifier sur simulateur.**
  - Passer sur Jules : l'Accueil le met à gauche.
  - Mettre l'objectif de Clément à 4 : l'anneau affiche « sur 4 ».
  - Choisir une photo : elle apparaît dans l'en-tête.
- [ ] **Étape 3 : installer sur l'iPhone de Clément**, branché et déverrouillé :
  - `cd ios && xcodegen && xcodebuild -project SuiviMuscu.xcodeproj -scheme SuiviMuscu -destination 'platform=iOS,name=iPhone de Clement' -allowProvisioningUpdates build` ;
  - puis `xcrun devicectl device install app --device 00008110-0001295A1EE1401E <chemin du .app>` ;
  - puis `xcrun devicectl device process launch --device 00008110-0001295A1EE1401E fr.suivimuscu.app`.
  - Attendu : l'appli s'ouvre sur le téléphone, vide (sans `-demo`) avec les deux profils.
  - Si iOS demande de faire confiance au développeur, Clément le fait dans Réglages → Général → VPN et gestion de l'appareil.
- [ ] **Étape 4 : commit** — `git commit -m "app: réglages et installation sur l'iPhone"`.

---

## À la fin de ce plan

- `cd ios/SuiviCore && swift test` : tous les tests passent.
- L'appli tourne sur l'iPhone de Clément. Une vraie séance peut y être faite de bout en bout, en pyramide, et l'Accueil montre les séances et les heures de la semaine.
- Ce qui reste pour les plans 2 à 4 :
  - Planning, tableau de charge, catalogue Machines, sauvegarde ;
  - les icônes maison ;
  - la synchro Supabase et TestFlight pour Jules.
