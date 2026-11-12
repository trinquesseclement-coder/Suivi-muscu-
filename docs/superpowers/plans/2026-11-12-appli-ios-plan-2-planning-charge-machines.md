# Suivi Muscu iOS, plan 2 : Planning, tableau de charge, Machines et sauvegarde

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objectif :** les trois onglets marqués « Bientôt » deviennent de vrais écrans, et l'appli devient complète en mode local :
- Planning (semaine par semaine, planifier pour soi, pour l'autre ou pour les deux) ;
- tableau de charge (Swift Charts animé) ;
- Machines (catalogue, corrections, photos, illustrations) ;
- en plus : la sauvegarde et l'import des données.

**Architecture :** on garde le découpage du plan 1. Les calculs vont dans `SuiviCore`, testés par `swift test` : semaine du planning, construction des séances planifiées, statistiques du tableau de charge, sauvegarde et import. Les écrans vont dans `SuiviMuscu`, avec les composants existants : `Theme`, `AppIcon`, `glassCard`, `Motion`, `Stepper`, `SchemeToggle`, `ExercisePicker`, `ProfileAvatar`.

**Technologies :** Swift 6.4, SwiftUI, Swift Charts, PhotosUI, UniformTypeIdentifiers, Swift Testing, XcodeGen, iOS 18.

**Brief :** `docs/superpowers/specs/2026-11-12-appli-ios-swiftui-design.md` (§4, §5, §8). Plan précédent : `docs/superpowers/plans/2026-11-12-appli-ios-plan-1-fondations.md`. L'appli web de référence est dans `appli/src/`.

**Branche :** `feat/appli-ios-plan-2`, partie de `feat/appli-ios` (PR #1).

## Contraintes globales

On reprend celles du plan 1, et elles valent pour chaque tâche :
- iOS 18.0 minimum, iPhone, portrait ;
- texte en français ;
- noms de champs JSON identiques au web ;
- couleurs et rayons de `Theme`, zones tactiles de 48 pt au moins ;
- animations de 350 ms au plus, jamais bloquantes, avec un fondu si « Réduire les animations » est actif ;
- icônes uniquement via `AppIcon` ;
- **aucune comparaison de charges entre Clément et Jules**.

Spécifiques au plan 2 :
- **Simulateur** : `iPhone Duo`, le seul runtime disponible. Commande : `-destination 'platform=iOS Simulator,name=iPhone Duo' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/sm-build`.
- **iPhone de Clément** : UDID `00008110-0001295A1EE1401E`, compilation en Release, équipe `5YNLG6QS4W`.
- **Fichiers étrangers** : on ne touche pas aux fichiers non commités qui ne viennent pas de ce plan (`appli/public/`, `ios/SuiviMuscu/Resources/Assets.xcassets/AppIcon.appiconset/`, `logo/`). On n'ajoute aux commits que ses propres fichiers.
- **Tableau de charge** : il montre **une personne à la fois** (« Moi » ou le prénom de l'autre). Il n'y a pas de vue « Les deux » pour les kilos.
  - C'est un écart volontaire au web, qui superpose les deux courbes. Il découle de l'anti-objectif du brief §4 et de l'audit du 11/11 (« ouvrir sur moi, une seule mesure »).
  - Les séances et les heures peuvent apparaître pour les deux, comme sur l'accueil.
- **Photo de machine** : JPEG d'environ 40 Ko, côté le plus long de 800 px, encodé hors du fil principal (même méthode que l'avatar du plan 1, sans recadrage carré).
- **Messages de commit** : en français, terminés par une ligne vide puis `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.

## Points de vigilance

1. **Planifier « pour les deux »** donne deux séances, chacune avec ses propres charges et son propre schéma (pyramide pour Clément, son choix pour Jules), reliées par un même `groupId`. Les charges de l'un ne doivent jamais se retrouver chez l'autre. → test `bothOwnersGetTheirOwnLoads`, tâche 1.
2. **Importer une sauvegarde** ne doit jamais effacer une séance plus récente déjà sur le téléphone. En cas de conflit, c'est le `updatedAt` le plus récent qui gagne. → test `importKeepsNewerLocalSession`, tâche 3.
3. **Une correction de machine venue du web** est partielle (seulement `id` et `note`). Elle ne doit plus rendre tout le fichier illisible : elle se fusionne sur la machine du catalogue. → test `partialOverrideMergesOntoCatalogue`, tâche 3.
4. **Masquer une machine** déjà utilisée dans d'anciennes séances : l'historique, les records et la « Dernière fois » continuent d'afficher son nom. → test `hiddenExerciseStillResolvesInHistory`, tâche 3.
5. **Semaine sans séance**, ou machine jamais faite : le tableau de charge affiche un état vide lisible (« Pas encore de séance cette semaine », « Pas encore fait »), pas un graphique vide ou cassé. → vérification sur simulateur, tâche 6.

---

## Arborescence (ajouts)

```
ios/SuiviCore/Sources/SuiviCore/
  PlanningWeek.swift      jours de la semaine, séances par jour triées, nombre d'exercices avec aide
  PlanBuilder.swift       « spécifications » d'exercices → séances planifiées pour 1 ou 2 personnes
  LoadStats.swift         stats par semaine, historique par machine, cardio, records (port de stats.ts)
  Backup.swift            export JSON compatible web et import avec fusion
ios/SuiviCore/Tests/SuiviCoreTests/
  PlanningTests.swift  PlanBuilderTests.swift  LoadStatsTests.swift  BackupTests.swift
ios/SuiviMuscu/
  Planning/  PlanningView.swift  PlanEditorView.swift  CopySessionSheet.swift
  Load/      LoadView.swift  WeekBarsChart.swift  MuscleSetsChart.swift  ProgressChart.swift  RecordsTable.swift  ChartCard.swift
  Machines/  MachinesView.swift  ExerciseFilters.swift  MachineEditor.swift  MachineSheet.swift  CameraPicker.swift  PhotoEncoder.swift
  Settings/  BackupSection.swift
```

---

### Tâche 1 : le cœur du planning

**Fichiers :** créer `PlanningWeek.swift`, `PlanBuilder.swift` ; tests dans `PlanningTests.swift` et `PlanBuilderTests.swift`

**Interfaces :**
- Consomme : `Dates`, `Rules.newItem`, `Rules.defaultScheme(for:)`, `Rules.needsHelp`, `Rules.titleSuggestion`, `Stats.lastPerformance`.
- Produit, pour le planning :
  - `PlanningWeek.days(containing iso: String) -> [String]` : les 7 dates du lundi au dimanche.
  - `PlanningWeek.sessions(on day: String, in sessions: [Session], profiles: [Profile]) -> [Session]` : triées par `slot` du propriétaire.
  - `PlanningWeek.helpCount(_ s: Session, profiles: [Profile], byId: [String: Exercise]) -> Int` : 0 si le propriétaire n'a pas besoin d'aide.
- Produit, pour construire une séance :
  - `struct PlanSpec: Identifiable, Hashable, Sendable { id: String; exerciseId: String; scheme: RepScheme?; sets: Int; reps: Int; kg: Double; minutes: Int }`.
  - `enum PlanTarget { case me, partner, both }`.
  - `PlanBuilder.spec(for ex: Exercise, owner: Profile?, sessions: [Session]) -> PlanSpec` :
    - avec un seul propriétaire : son schéma par défaut et ses charges de la dernière fois (logique `specFor` du web) ;
    - pour les deux : schéma `nil`, réglé ensuite pour chacun.
  - `PlanBuilder.items(from specs: [PlanSpec], owner: Profile, single: Bool, sessions: [Session], byId: [String: Exercise]) -> [SessionItem]`.
  - `PlanBuilder.sessions(specs:target:me:partner:date:title:notes:sessions:byId:now:) -> [Session]` : nouvelles séances `planned`, `createdBy` = moi, et un `groupId` commun si elles sont deux.
  - `PlanBuilder.specs(from s: Session) -> [PlanSpec]` : pour « Reprendre une séance » et pour modifier une séance existante.
  - `PlanBuilder.groupingHelp(_ specs: [PlanSpec], byId:) -> [PlanSpec]` : regroupe les exercices avec aide là où apparaît le premier (logique `groupHelp` du web).

**Règles :**
- **Un seul propriétaire, spec en pyramide** : les éléments viennent de `Rules.newItem(ex, ownerId:, sessions:, scheme: .pyramid)`, donc 12/10/8/12 et charges série par série.
- **Un seul propriétaire, spec classique** : `sets` séries × `reps`, toutes à `kg`, non faites.
- **Pour les deux** : chaque séance est construite avec `Rules.newItem(ex, ownerId: owner.id, sessions:, scheme: Rules.defaultScheme(for: owner))`. Les champs `sets`, `reps` et `kg` de la spec sont ignorés pour la muscu.
- **Cardio** : `minutes` de la spec, `level` repris de la dernière fois du propriétaire.
- **Titre vide** : `Rules.titleSuggestion` à partir des exercices.

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `weekDaysStartMonday` : `days(containing: "2026-11-12")` commence par `"2026-11-09"` et finit par `"2026-11-15"`.
  - `daySessionsSortedBySlot` : la séance de Jules (slot 2) passe après celle de Clément (slot 1) le même jour.
  - `helpCountOnlyForHelpedOwner` : une séance de Clément avec `d-presse-45` et `m-chest-press` donne 1 ; la même pour Jules donne 0.
  - `bothOwnersGetTheirOwnLoads` :
    - historique : Clément a fait `m-chest-press` en pyramide 20/25/30/20 ; Jules l'a fait en classique 3×10 à 60 kg ;
    - planifier « pour les deux » avec `m-chest-press` donne 2 séances avec le même `groupId` non nul ;
    - Clément obtient 4 séries `[20,25,30,20]` et reps `[12,10,8,12]` ;
    - Jules obtient 3 séries à 60 kg et 10 répétitions ;
    - aucune charge de l'un ne se trouve chez l'autre.
  - `singleOwnerClassicSpecBuildsSets` : spec classique 4×8 à 42,5 kg → 4 séries `kg == 42.5`, `reps == 8`, `done == false`.
  - `emptyTitleUsesSuggestion` : un titre vide avec deux exercices de pecs donne `"Push"`.
  - `groupingHelpMovesHelpTogether` : `[a, H1, b, H2]` donne `[a, H1, H2, b]`.
- [ ] **Étape 2 : les lancer** — `cd ios/SuiviCore && swift test --filter "Planning|PlanBuilder"`. Attendu : échec de compilation.
- [ ] **Étape 3 : implémenter** les deux fichiers.
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent.
- [ ] **Étape 5 : commit** — `core: semaine du planning et construction des séances planifiées`.

### Tâche 2 : les statistiques du tableau de charge

**Fichiers :** créer `LoadStats.swift` ; tests dans `LoadStatsTests.swift`

**Interfaces :**
- Produit :
  - `struct WeekLoad: Sendable, Equatable { week: String; sessions: Int; minutes: Int; tonnage: Double; sets: Int; cardioMinutes: Int; setsByMuscle: [Muscle: Int] }`.
  - `LoadStats.weeks(_ sessions: [Session], ownerId: String, byId: [String: Exercise], count: Int, today: String, now: Date) -> [WeekLoad]` : `count` semaines, de la plus ancienne à la plus récente. Les séances et les minutes suivent les règles de `Stats.counts` et `Stats.durationMinutes`. Le reste est le port de `weeklyStats` du web.
  - `struct ExercisePoint: Sendable, Equatable { date, sessionId, topKg, topReps, e1rm, tonnage }`.
  - `LoadStats.history(_ sessions:, ownerId:, exerciseId:) -> [ExercisePoint]` : port de `exerciseHistory`.
  - `struct CardioPoint` et `LoadStats.cardioHistory(...)` : port de `cardioHistory`.
  - `struct PR` et `LoadStats.records(_ sessions:, ownerId:) -> [String: PR]` : port de `personalRecords`.
  - `LoadStats.doneExerciseIds(_ sessions:, ownerId:) -> [String]` : les machines déjà faites, triées par dernière date. Elles alimentent le menu « Choisir une machine ».

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `weeksAreOldestFirstAndCount8` : 8 éléments, dont le dernier est la semaine d'aujourd'hui.
  - `weekLoadSumsTonnageAndMuscles` :
    - une séance `m-chest-press` de 2 séries faites 40×10, plus 1 série non faite, donne `tonnage == 800`, `sets == 2` et `setsByMuscle[.pecs] == 2` ;
    - une séance cardio de 15 minutes faites donne `cardioMinutes == 15`.
  - `historyTopSetAndE1rm` : les séries 40×10 et 45×8 donnent `topKg == 45`, `topReps == 8` et `e1rm == 45 * (1 + 8/30)`.
  - `recordsKeepBestE1rm` : le meilleur e1rm sur 3 séances est retenu ; à égalité, la date la plus ancienne gagne.
  - `doneExerciseIdsMostRecentFirst`.
- [ ] **Étape 2 : les lancer** — attendu : échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent.
- [ ] **Étape 5 : commit** — `core: statistiques du tableau de charge`.

### Tâche 3 : la sauvegarde, l'import et des corrections de machine plus tolérantes

**Fichiers :** créer `Backup.swift` ; modifier `AppStore.swift` (chargement tolérant, `importData`, `exportData`) ; tests dans `BackupTests.swift` et `StoreTests.swift`

**Interfaces :**
- Produit :
  - `Backup.export(profiles:sessions:exercises:now:) -> Data` : un JSON joliment indenté au format du web, `{ "version": 1, "exportedAt": ISO, "profiles": {id: …}, "sessions": {id: …}, "exercises": {id: …} }`.
  - `Backup.decode(_ data: Data) throws -> BackupContent`, avec `BackupContent { profiles: [String: Profile]; sessions: [String: Session]; exercises: [String: ExerciseOverride] }`.
    - Il accepte un fichier exporté par le web ou par l'iOS.
    - Les champs inconnus sont ignorés.
    - Une séance ou une correction illisible est ignorée et comptée. On ne rejette pas tout le fichier.
  - `struct ExerciseOverride: Codable, Sendable` : tous les champs d'`Exercise` sont optionnels sauf `id`. `func applied(to base: Exercise?) -> Exercise?` fusionne champ par champ. Pour une machine perso sans base, il faut au minimum `name`, `kind` et `muscle`.
  - `AppStore.exportData() -> Data`.
  - `AppStore.importData(_ data: Data) throws -> ImportSummary`, avec `ImportSummary { added: Int; updated: Int; kept: Int; skipped: Int }`.
    - Pour chaque séance, la plus récente gagne selon `updatedAt` (`kept` compte les locales gardées parce que plus récentes).
    - Les corrections de machines sont fusionnées. Les profils ne sont jamais remplacés : seuls `avatar` et `settings` sont pris s'ils manquent localement.
    - Une seule écriture à la fin.
  - Le chargement d'`AppStore` lit désormais `exercises` comme `[String: ExerciseOverride]` et le fusionne sur `Catalogue.base`. C'est ce qui corrige la remarque différée de la tâche 5 du plan 1.
  - `AppStore.exerciseAnyById: [String: Exercise]` : inclut les machines masquées (`deleted`). Il sert à l'historique, aux records et à « Dernière fois ».

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `exportRoundTrip` : `decode(export(...))` redonne les mêmes séances et profils.
  - `decodesWebExport` : un JSON du web en dur (`version`, `exportedAt`, une séance, une correction `{ "id": "m-chest-press", "note": "Siège cran 4" }`) se décode.
  - `partialOverrideMergesOntoCatalogue` : un fichier store contenant cette correction partielle se charge sans aller en `.corrupt`. `exerciseById["m-chest-press"]` a la note et garde `posture == .transfert` et `step == 5`.
  - `importKeepsNewerLocalSession` : la séance locale a un `updatedAt` plus récent que celle importée ; elle reste, et `kept == 1`.
  - `importAddsAndUpdates` : une nouvelle séance donne `added == 1` ; une séance importée plus récente donne `updated == 1`.
  - `importSkipsUnreadableSession` : une séance illisible parmi 3 donne `skipped == 1`, et les 2 autres sont importées.
  - `hiddenExerciseStillResolvesInHistory` : après `saveExercise` avec `deleted = true`, la machine n'est plus dans `exercises` mais reste dans `exerciseAnyById`.
- [ ] **Étape 2 : les lancer** — attendu : échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent, y compris ceux du plan 1.
- [ ] **Étape 5 : commit** — `core: sauvegarde, import et corrections de machines tolérantes`.

### Tâche 4 : l'écran Planning

**Fichiers :** créer `Planning/PlanningView.swift` ; modifier `RootView.swift` (l'onglet Planning remplace « Bientôt »)

**Interfaces :**
- Consomme : `PlanningWeek` (tâche 1), `Rules.isLive`, `AppStore`, `Format`, la navigation du plan 1 (`onOpenSession`, transition zoom).
- Produit : `PlanningView(onOpenSession: (String) -> Void, onPlan: (_ date: String) -> Void, onEditPlan: (_ sessionId: String) -> Void)`.

**Ce qu'on voit (reprendre `appli/src/pages/Planning.tsx` et `maquette/img/03-planning.jpg`) :**
- **En-tête :** « Planning », avec « Semaine du 9 nov. au 15 nov. · KOMEX ».
- **Navigation :** ‹ « Cette semaine » ›. Le bouton du milieu est désactivé sur la semaine en cours. On peut aussi changer de semaine en balayant horizontalement.
- **Légende :** une pastille par profil, avec « (toi) », et « Pointillés = prévue ».
- **Une carte, une ligne par jour :**
  - à gauche, le jour abrégé et sa date ; aujourd'hui est mis en avant (pastille foncée) ;
  - à droite, les séances du jour, avec une barre de la couleur du propriétaire, le titre et « Jules · 3 exos · faite / en cours » ;
  - un bord en pointillés si la séance est prévue ;
  - un badge `AppIcon.help` avec un nombre s'il y a des exercices avec aide.
- **Actions :**
  - « + Planifier » en pointillés sur chaque jour à partir d'aujourd'hui. Un jour passé sans séance affiche « — ».
  - Toucher une séance faite ou en cours l'ouvre (`onOpenSession`).
  - Toucher une séance prévue que *j'ai créée* ouvre l'éditeur (`onEditPlan`) ; sinon elle s'ouvre normalement.
- **Animation :** au changement de semaine, les lignes glissent dans le sens du changement (en fondu si les animations sont réduites).

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur** avec `-demo`. Capturer la semaine en cours, puis la semaine précédente. Attendu : les séances de démo aux bons jours, le jeudi mis en avant, « Séance à deux » en pointillés vendredi pour les deux. Comparer à `03-planning.jpg`.
- [ ] **Étape 3 : commit** — `app: écran Planning`.

### Tâche 5 : l'éditeur de séance planifiée

**Fichiers :** créer `Planning/PlanEditorView.swift`, `Planning/CopySessionSheet.swift` ; modifier `RootView.swift` (navigation), `Session/SessionView.swift` (option « Modifier la séance » pour une séance prévue que j'ai créée et pas encore commencée)

**Interfaces :**
- Consomme : `PlanBuilder` (tâche 1), `ExercisePicker` (plan 1, avec un nouveau paramètre `owner: Profile?` qui choisit le schéma), `Stepper`, `SchemeToggle`, `AppStore.saveSession`, `deleteSession`.
- Produit : `PlanEditorView(sessionId: String?, date: String?)`.

**Ce qu'on voit (reprendre `appli/src/pages/PlanEditor.tsx`) :**
- **Titre :** « Planifier », ou « Modifier la séance » si elle existe déjà.
- **Date :** un `DatePicker` compact, en français.
- **« Pour qui » :** contrôle segmenté de 48 pt, « Les deux » / « Moi » / prénom de l'autre.
  - Une séance existante ne propose que « Moi » / prénom.
  - Avec « Les deux », la ligne d'aide dit « Une séance chacun, avec les charges et la façon de faire de chacun. »
- **« Nom » :** champ dont le texte d'exemple est le titre suggéré.
- **« Exercices » :** une carte par exercice, avec vignette, nom, badges, et les boutons Monter, Descendre et Retirer (48 pt).
  - Pour un seul propriétaire, en muscu : `SchemeToggle`. En pyramide, on lit « 12 · 10 · 8 · 12, charges de la dernière fois » ; en classique, trois steppers « Séries », « Reps » et « Charge ».
  - Pour les deux : la ligne « Charges de la dernière fois de chacun ».
  - Cardio : un stepper « Minutes » par pas de 5.
- **Sous la liste :**
  - « Ajouter des exercices » ouvre `ExercisePicker` ;
  - « Reprendre une séance » ouvre une feuille avec les 30 dernières séances non vides : titre, prénom, date, nombre d'exercices ;
  - si au moins 2 exercices avec aide sont dispersés et que l'aide concerne un propriétaire, une bannière propose « Regrouper les exercices avec Jules » (`groupingHelp`).
- **« Notes » :** texte libre, avec l'exemple « Ex. : arriver tôt, la presse est souvent prise vers 18 h ».
- **Barre du bas :**
  - « Supprimer » pour une séance existante, avec confirmation ;
  - le bouton principal « Planifier pour les deux », « Planifier » ou « Enregistrer », désactivé sans exercice.
  - Enregistrer revient au Planning, sur la semaine de la date choisie.
- **Modifier une séance existante :** les éléments sont reconstruits depuis les specs pour le même propriétaire, avec le même `id` de séance, `groupId` et `createdBy`.

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur** avec `-demo`, comme Clément :
  1. Planifier pour les deux samedi, avec `m-chest-press` et `d-presse-45`.
  2. Attendu dans le Planning : deux séances en pointillés samedi.
  3. Ouvrir celle de Clément : pyramide.
  4. Ouvrir celle de Jules (en lecture) : ses propres charges.
  5. Modifier la séance de Clément (retirer un exercice) : le changement est enregistré.
  6. « Reprendre une séance » préremplit les exercices.
- [ ] **Étape 3 : commit** — `app: préparer et modifier une séance planifiée`.

### Tâche 6 : le tableau de charge

**Fichiers :** créer `Load/LoadView.swift`, `Load/ChartCard.swift`, `Load/WeekBarsChart.swift`, `Load/MuscleSetsChart.swift`, `Load/ProgressChart.swift`, `Load/RecordsTable.swift` ; modifier `RootView.swift`

**Interfaces :**
- Consomme : `LoadStats` (tâche 2), `Stats.formatHours`, `Format`, `Theme.color(for:)`, `AppStore.exerciseAnyById`.
- Produit : `LoadView()`. `ChartCard(title:subtitle:content:table:)` affiche un bouton « Voir le tableau » / « Voir le graphique ».

**Ce qu'on voit (reprendre `appli/src/pages/Stats.tsx`, avec le choix « une personne à la fois » des contraintes globales) :**
- **En-tête :** « Tableau de charge », avec « Les 8 dernières semaines ».
- **Sélecteur :** « Moi » / prénom de l'autre, 48 pt, sur « Moi » par défaut.
- **« Séances et heures par semaine »** : barres de séances, avec les heures en libellé au-dessus de chaque barre (`formatHours`). Seul graphique qui peut montrer les deux personnes côte à côte : c'est une interrupteur « Avec Jules », désactivé par défaut.
- **« Tonnage par semaine »** : barres, sous-titre « Kilos × répétitions des séries validées ».
- **« Cardio par semaine »** : barres en minutes.
- **« Séries par muscle »** : barres horizontales pour la semaine en cours, avec la bande de repère 10–20 et le sous-titre « Cette semaine — repère : 10 à 20 séries par muscle et par semaine ».
- **« Progression par machine »** :
  - un menu des machines déjà faites (`doneExerciseIds`) ;
  - en muscu, un segmenté « Charge max » / « 1RM estimé » / « Tonnage » et une courbe avec des points ;
  - en cardio, une courbe en minutes.
- **« Records »** : un tableau Machine / Meilleure série / 1RM estimé / Date, pour la personne choisie.
- **États vides :**
  - « Pas encore de séance cette semaine » ;
  - « Pas encore fait » pour une machine ;
  - « Pas encore de record ».

**Animations (brief §8) :**
- Les barres poussent depuis 0, l'une après l'autre (`Motion.stagger`), à l'apparition et au changement de personne.
- Changer de mesure ou de machine fait glisser les barres et la courbe vers les nouvelles valeurs (animation de Swift Charts sur la valeur).
- La courbe se dessine de gauche à droite à l'apparition.
- Avec « Réduire les animations », on passe à un simple fondu.

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur** avec `-demo`. Capturer comme Clément, puis avec le sélecteur sur Jules, puis le tableau d'un graphique, puis une machine jamais faite et une semaine vide (en lançant sans `-demo`). Attendu : les chiffres de la démo, aucun kilo des deux personnes sur un même graphique, et les états vides lisibles.
- [ ] **Étape 3 : commit** — `app: tableau de charge animé`.

### Tâche 7 : le catalogue Machines

**Fichiers :**
- créer `Machines/MachinesView.swift`, `ExerciseFilters.swift`, `MachineEditor.swift`, `MachineSheet.swift`, `CameraPicker.swift`, `PhotoEncoder.swift` ;
- modifier `Session/ExercisePicker.swift` (réutilise `ExerciseFilters`), `Session/ExerciseCard.swift` (toucher la vignette ouvre `MachineSheet`), `RootView.swift`, `ios/project.yml` (ajouter `NSCameraUsageDescription` : « Pour photographier les machines de la salle et les reconnaître du premier coup d'œil. »).

**Interfaces :**
- Consomme : `AppStore.exercises`, `saveExercise`, `Rules.helperName`, `Illustrations.urls(for:)`, `Illustrations.isApproximate`, l'encodage hors fil principal de `AvatarPicker` (plan 1).
- Produit :
  - `ExerciseFilters(state: Binding<FilterState>, helperName: String?)`, avec `struct FilterState: Codable { query, posture, help, muscle }`, enregistré par écran (`machines.filters`, `picker.filters`). Le filtre de posture du sélecteur garde la clé du plan 1, `picker.posture`.
  - `MachineSheet(exercise: Exercise)` ;
  - `MachineEditor(exercise: Exercise, isNew: Bool)` ;
  - `PhotoEncoder.dataURL(from data: Data) async -> String?` : côté le plus long 800 px, environ 40 Ko.

**Ce qu'on voit (reprendre `appli/src/pages/Machines.tsx`, `components/ExerciseMedia.tsx` et les captures `13-machines.jpg`, `14-machine-edition.jpg`, `08-fiche-machine.jpg`) :**
- **En-tête :** « Machines », avec « KOMEX · 70 exercices · touche pour corriger », et un bouton « + » pour ajouter une machine perso.
- **Filtres :** recherche ; posture « Depuis le fauteuil » / « Transfert » / « Debout » ; aide ; muscle.
- **Liste :** deux sections, « Musculation » et « Cardio », avec leur nombre. Chaque ligne a :
  - une vignette (la photo si elle existe, sinon l'illustration) ;
  - le nom ;
  - les badges muscle, posture et « Aide Jules » ;
  - « Technogym · machine à plaques » ;
  - la note.
- **Toucher la vignette** ouvre `MachineSheet`, en feuille :
  - le bandeau « Réglage : … » ;
  - « Ta machine à la salle » : « Prendre la machine en photo » avec l'appareil photo (sur simulateur, choisir dans la photothèque), « Changer », « Retirer » ;
  - « Le mouvement » : départ et arrivée qui alternent toutes les 1,2 s en fondu (images fixes côte à côte si les animations sont réduites), avec « mouvement proche » si `isApproximate` ;
  - le crédit « Illustrations : free-exercise-db (photos d'origine Bodybuilding.com) ».
- **Toucher la ligne** ouvre `MachineEditor` :
  - Nom ;
  - Type (machine perso seulement) ;
  - Posture (« Fauteuil » / « Transfert » / « Debout ») ;
  - Aide (« Seul » / « Avec Jules ») ;
  - pour la muscu : Muscle principal, Équipement, Marque, et « Pas des boutons +/− » (stepper 0,5…10 par pas de 1,25) ;
  - « Note (réglages, numéro de la machine…) » ;
  - en bas : « Masquer » (machine du catalogue) ou « Supprimer » (machine perso), avec confirmation, puis « Enregistrer ».
  - Masquer met `deleted = true` : la machine sort de la liste mais reste dans l'historique (`exerciseAnyById`, tâche 3).
- **Séance :** toucher une vignette ouvre aussi `MachineSheet`, ce qui permet de prendre la photo en pleine séance.

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur.**
  1. Filtrer « Depuis le fauteuil » : seules les poulies et les machines fauteuil restent.
  2. Ouvrir une fiche : le mouvement alterne.
  3. Ajouter une photo depuis la photothèque : elle apparaît dans la liste et dans la séance. Mesurer la taille stockée : environ 40 Ko.
  4. Corriger la note d'une machine : elle apparaît en séance.
  5. Masquer `d-tbar` : il disparaît de la liste et du sélecteur.
  6. Ajouter une machine perso « Presse Hammer test » : elle apparaît, puis la supprimer.
- [ ] **Étape 3 : commit** — `app: catalogue Machines, fiche, photos et corrections`.

### Tâche 8 : la sauvegarde dans les Réglages

**Fichiers :** créer `Settings/BackupSection.swift` ; modifier `Settings/SettingsView.swift`

**Interfaces :**
- Consomme : `AppStore.exportData()`, `importData(_:)`, `ImportSummary` (tâche 3).

**Ce qu'on voit :**
- **Section « Sauvegarde »**, avec le texte « Fais un export de temps en temps : il contient toutes vos séances, les réglages des machines et vos photos. »
- **« Exporter »** : un `ShareLink` vers un fichier temporaire `suivi-muscu-2026-11-12.json`, à envoyer par AirDrop, Fichiers ou WhatsApp.
- **« Importer »** : `fileImporter` sur les fichiers `.json`, puis une confirmation qui annonce le contenu (« 12 séances, 3 réglages de machines ») avant d'importer.
  - Après l'import : « 10 ajoutées, 2 mises à jour, 0 gardée (plus récente sur ce téléphone) ».
  - En cas d'erreur : « Ce fichier n'est pas une sauvegarde Suivi Muscu. »

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur.**
  1. Exporter avec `-demo`. Récupérer le fichier dans le conteneur de l'appli : `xcrun simctl get_app_container booted fr.suivimuscu.app data`.
  2. Relancer sans `-demo` sur un store vide.
  3. Importer le fichier en le plaçant dans les Fichiers du simulateur (`xcrun simctl addmedia` ne prend pas le JSON : passer par un argument DEBUG `-import-file <chemin>` si besoin).
  4. Attendu : les séances de démo réapparaissent, avec le résumé.
- [ ] **Étape 3 : commit** — `app: export et import de la sauvegarde`.

### Tâche 9 : installation et vérification sur l'iPhone de Clément

**Fichiers :** aucun, sauf un correctif si la vérification en révèle un.

- [ ] **Étape 1 : compiler et installer** en Release :
  - `cd ios && xcodegen && xcodebuild -project SuiviMuscu.xcodeproj -scheme SuiviMuscu -configuration Release -destination 'id=00008110-0001295A1EE1401E' -allowProvisioningUpdates -derivedDataPath /tmp/sm-device build` ;
  - puis `xcrun devicectl device install app --device 00008110-0001295A1EE1401E /tmp/sm-device/Build/Products/Release-iphoneos/SuiviMuscu.app` ;
  - puis `xcrun devicectl device process launch --device 00008110-0001295A1EE1401E fr.suivimuscu.app`.
  - Les données réelles du téléphone sont conservées : ne jamais passer `-demo`, de toute façon inactif en Release.
- [ ] **Étape 2 : capturer** chaque onglet avec `xcrun devicectl device capture screenshot --device 00008110-0001295A1EE1401E --destination <fichier>`.
  - Il faut que l'utilisateur touche les onglets ; si personne n'est là, capturer au moins l'onglet affiché au lancement.
  - Vérifier que rien ne déborde en 390 pt de large.
- [ ] **Étape 3 :** s'il y a un correctif, le faire, le committer, puis réinstaller.

---

## À la fin de ce plan

- `cd ios/SuiviCore && swift test` : tous les tests passent, ceux du plan 1 compris.
- Plus aucun onglet « Bientôt ». En mode local, l'appli fait tout ce que faisait l'appli web, et une sauvegarde peut passer d'un téléphone à l'autre.
- Restent pour les plans 3 et 4 : les icônes maison (VectorCraft), la synchro Supabase et TestFlight pour Jules.
