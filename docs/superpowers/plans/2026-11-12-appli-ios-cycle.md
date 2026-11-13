# Suivi Muscu iOS : « Mon cycle »

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objectif :** Clément et Jules tournent sur trois séances, l'une après l'autre, sans jours fixes : épaules + dos, puis pecs + bras, puis cardio, et ça repart. L'accueil propose la suivante du cycle ; un toucher crée la séance du jour, pour les deux ou pour soi, avec les charges de la dernière fois de chacun.

**Pourquoi un cycle plutôt que 15 séances datées :** des séances créées d'avance figent les charges au moment de leur création et leurs dates se décalent dès qu'un jour saute. Ici la séance est créée au moment où on la commence. Validé par Clément le 12/11/2026 (« Oui, fais-le »).

**Architecture :** le modèle et les règles vont dans `SuiviCore` (testés par `swift test`). L'écran d'accueil reçoit une carte, les Réglages une section et un éditeur. On réutilise `PlanBuilder` (plan 2) pour construire les séances : c'est lui qui garantit que chacun a ses propres charges.

**Technologies :** Swift 6, SwiftUI, Swift Testing, XcodeGen, iOS 18.

**Brief général :** `docs/superpowers/specs/2026-11-12-appli-ios-swiftui-design.md`. Suites du plan 2 : `docs/superpowers/plans/2026-11-12-appli-ios-plan-2-suites.md`.

**Branche :** `feat/appli-ios-cycle`, partie de `feat/appli-ios-plan-2`.

## Contraintes globales

- iOS 18.0 minimum, iPhone, portrait ; texte en français, mots simples.
- Couleurs et rayons de `Theme`, zones tactiles de 48 pt au moins, textes en styles Dynamic Type.
- Animations de 350 ms au plus, jamais bloquantes, avec un fondu si « Réduire les animations » est actif.
- Icônes uniquement via `AppIcon`.
- **Aucune comparaison ni mélange des charges de Clément et de Jules.** La séance de chacun est construite à partir de son propre historique.
- Noms de champs JSON existants inchangés ; les nouveaux champs sont optionnels (un fichier d'avant le cycle doit se charger tel quel).
- Les garanties du fichier de données du plan 1 restent vraies : écriture atomique, `lastSaveError`, `loadProblem`, copie `.corrupt` jamais supprimée.
- Simulateur : `iPhone Duo`. Vrai iPhone : installation seulement, aucun lancement automatique.
- Fichiers étrangers : on ne touche pas à `appli/public/`, `ios/SuiviMuscu/Resources/Assets.xcassets/AppIcon.appiconset/`, `logo/`.
- Messages de commit en français, terminés par une ligne vide puis la ligne `Co-Authored-By:` du modèle qui a écrit le code.

## Points de vigilance

1. **« Commencer avec Jules »** crée deux séances reliées par un `groupId`, chacune avec les charges et le schéma de son propriétaire. → test `bothGetTheirOwnLoadsFromCycle`, tâche 1.
2. **Le cycle avance sur ce qui a été fait, pas sur ce qui a été créé.** Une séance du cycle créée puis abandonnée sans série validée ne fait pas avancer le cycle. → test `abandonedSessionDoesNotAdvance`, tâche 1.
3. **Chacun avance à son rythme.** Si Jules rate une séance, sa « suivante » n'est pas celle de Clément. → test `nextIsPerPerson`, tâche 1.
4. **Un fichier de données d'avant le cycle** (sans `cycle`, séances sans `cycleId`) se charge sans copie `.corrupt` et donne le cycle de départ. → test `oldStoreFileLoadsWithStandardCycle`, tâche 1.
5. **Une machine masquée ou supprimée** présente dans une séance du cycle est ignorée à la création ; si la séance n'a plus aucun exercice, on ne crée rien et l'écran le dit. → test `hiddenExercisesAreSkipped`, tâche 1 ; message à l'écran, tâche 2.

---

## Arborescence (ajouts)

```
ios/SuiviCore/Sources/SuiviCore/
  Cycle.swift            modèle (Cycle, CycleTemplate, CycleItem), cycle de départ
  CyclePlanner.swift     séance suivante, quand proposer le cycle, construction des séances
ios/SuiviCore/Tests/SuiviCoreTests/
  CycleTests.swift
ios/SuiviMuscu/
  Cycle/     CycleCard.swift  CyclePickerSheet.swift  CycleTemplateEditor.swift
  Settings/  CycleSection.swift
```

---

### Tâche 1 : le modèle et les règles du cycle

**Fichiers :** créer `Cycle.swift`, `CyclePlanner.swift`, `CycleTests.swift` ; modifier `Model.swift` (`Session.cycleId`), `AppStore.swift` (stockage du cycle), `Backup.swift` (export et import du cycle) ; compléter `StoreTests.swift` et `BackupTests.swift`.

**Interfaces :**
- Consomme : `PlanBuilder.spec(for:owner:sessions:)`, `PlanBuilder.sessions(specs:target:me:partner:date:title:notes:sessions:byId:now:)`, `PlanTarget`, `Stats.counts`, `Rules.isLive`.
- Produit :
  - `struct CycleItem: Codable, Hashable, Sendable { exerciseId: String; minutes: Int? }` (`minutes` ne sert qu'au cardio).
  - `struct CycleTemplate: Codable, Hashable, Identifiable, Sendable { id: String; title: String; items: [CycleItem] }`.
  - `struct Cycle: Codable, Hashable, Sendable { templates: [CycleTemplate] }` et `Cycle.standard` (le cycle de départ, ci-dessous).
  - `Session.cycleId: String?` : l'identifiant de la séance type d'où vient la séance. Champ optionnel, absent du JSON quand il est nul.
  - `CyclePlanner.last(_ cycle: Cycle, sessions: [Session], ownerId: String) -> CycleTemplate?` : la séance type de la dernière séance du cycle **qui compte** (`Stats.counts`) de cette personne, non supprimée, dont le `cycleId` existe encore dans le cycle. `sessions` est trié du plus récent au plus ancien, comme `AppStore.sessions`.
  - `CyclePlanner.next(_ cycle: Cycle, sessions: [Session], ownerId: String) -> CycleTemplate?` : celle qui suit `last` dans l'ordre du cycle, en bouclant ; la première s'il n'y a pas de `last` ; `nil` si le cycle est vide.
  - `CyclePlanner.offersCycle(sessions: [Session], ownerId: String, today: String, now: Date) -> Bool` : vrai quand la personne n'a ni séance en cours (`Rules.isLive`) ni séance prévue datée d'aujourd'hui.
  - `CyclePlanner.partnerIsFree(sessions: [Session], partnerId: String, today: String, now: Date) -> Bool` : même règle pour l'autre ; sert à proposer ou non « Commencer avec … ».
  - `CyclePlanner.sessions(for template: CycleTemplate, target: PlanTarget, me: Profile, partner: Profile, date: String, sessions: [Session], byId: [String: Exercise], now: Date) -> [Session]` : séances `planned` datées `date`, titre = `template.title`, `cycleId = template.id`, `createdBy = me.id`, `groupId` commun si elles sont deux. Tableau vide si aucun exercice de la séance type n'existe dans `byId`.
  - `AppStore.cycle: Cycle` (le cycle enregistré, sinon `Cycle.standard`) et `AppStore.saveCycle(_ cycle: Cycle)`.
  - `BackupContent.cycle: Cycle?`.

**Règles :**
- **Construction** : pour chaque `CycleItem` dont l'exercice est dans `byId`, une spec `PlanBuilder.spec(for:owner:sessions:)` avec `owner` = le propriétaire s'il est seul, `nil` pour `.both`. Pour le cardio, `minutes` de l'item remplace celles de la spec quand il est renseigné. Puis `PlanBuilder.sessions(...)`. On ne réécrit aucune règle de charges ici.
- **Stockage** : le fichier de données gagne une clé optionnelle `cycle`. Absente ou illisible, on prend `Cycle.standard` sans envoyer le fichier en `.corrupt`. `saveCycle` écrit le fichier comme les autres enregistrements.
- **Sauvegarde** : l'export contient `cycle` s'il a été enregistré. À l'import, le cycle du fichier n'est pris que si le téléphone n'en a pas d'enregistré.
- **Cycle de départ** (`Cycle.standard`) :

  | `id` | Titre | Exercices, dans l'ordre |
  |---|---|---|
  | `cycle-epaules-dos` | Épaules + dos | `m-lat-pulldown`, `m-rowing`, `poulie-tirage-horizontal`, `m-shoulder-press`, `m-elevation-laterale`, `poulie-face-pull`, `poulie-crunch` |
  | `cycle-pecs-bras` | Pecs + bras | `m-chest-press`, `m-chest-press-incline`, `m-pec-deck`, `m-curl`, `poulie-triceps`, `m-dips-assis`, `m-crunch` |
  | `cycle-cardio` | Cardio | `c-escalier` (15 min), `c-tapis` (15 min), `c-skierg` (10 min), `poulie-rotation-buste` |

- [ ] **Étape 1 : écrire les tests qui échouent**
  - `standardCycleUsesCatalogueExercises` : 3 séances types ; chaque `exerciseId` existe dans `Catalogue.base`.
  - `nextIsFirstWithoutHistory` : sans séance, `next` est `cycle-epaules-dos` et `last` est `nil`.
  - `nextFollowsLastCountingSession` : dernière séance du cycle qui compte = `cycle-epaules-dos` → `next` = `cycle-pecs-bras` ; après `cycle-cardio` → `cycle-epaules-dos` (boucle).
  - `abandonedSessionDoesNotAdvance` : une séance `cycle-pecs-bras` plus récente mais sans série validée ne change pas `next`.
  - `nextIsPerPerson` : Clément a fait `cycle-epaules-dos` puis `cycle-pecs-bras`, Jules seulement `cycle-epaules-dos` → `next` de Clément = `cycle-cardio`, de Jules = `cycle-pecs-bras`.
  - `removedTemplateIsIgnored` : une séance dont le `cycleId` n'existe plus dans le cycle est ignorée par `last`.
  - `emptyCycleHasNoNext`.
  - `offersCycleWhenNothingToday` : faux avec une séance prévue aujourd'hui ou une séance en cours ; vrai avec seulement une séance prévue dans 3 jours ou une séance terminée aujourd'hui.
  - `bothGetTheirOwnLoadsFromCycle` : historique Clément `m-chest-press` en pyramide 20/25/30/20, Jules en classique 3×10 à 60 kg ; `sessions(for: pecs-bras, target: .both, …)` donne 2 séances de même `groupId` non nul, `cycleId == "cycle-pecs-bras"`, titre « Pecs + bras » ; Clément a `[20,25,30,20]` en reps `[12,10,8,12]`, Jules 3 séries à 60 kg ; aucune charge de l'un chez l'autre.
  - `singleTargetBuildsOneSession` : `.me` donne une séance, `groupId` nul, propriétaire = moi.
  - `cardioTakesTemplateMinutes` : `c-escalier` de la séance cardio a `minutes == 15`.
  - `hiddenExercisesAreSkipped` : `byId` sans `m-pec-deck` → la séance a 6 exercices ; `byId` vide → `[]`.
  - `oldStoreFileLoadsWithStandardCycle` (StoreTests) : un fichier sans `cycle` et une séance sans `cycleId` se charge, aucun fichier `.corrupt`, `store.cycle == Cycle.standard`.
  - `savedCycleSurvivesReload` (StoreTests) : `saveCycle` puis un nouvel `AppStore(fileURL:)` redonne le même cycle ; la séance avec `cycleId` garde son `cycleId`.
  - `unreadableCycleFallsBackToStandard` (StoreTests) : `"cycle": 42` dans le fichier → cycle de départ, pas de `.corrupt`, les séances sont là.
  - `backupCarriesCycle` (BackupTests) : `decode(export(...))` redonne le cycle ; un import ne remplace pas un cycle déjà enregistré, mais le prend s'il n'y en a pas.
- [ ] **Étape 2 : les lancer** — `cd ios/SuiviCore && swift test --filter "Cycle|Store|Backup"`. Attendu : échec de compilation.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 : vérifier** — `swift test`. Attendu : tous les tests passent, ceux d'avant compris (142).
- [ ] **Étape 5 : commit** — `core: cycle de séances (modèle, séance suivante, construction, stockage)`.

### Tâche 2 : la carte du cycle sur l'accueil

**Fichiers :** créer `Cycle/CycleCard.swift`, `Cycle/CyclePickerSheet.swift` ; modifier `Home/HomeView.swift`.

**Interfaces :**
- Consomme : `AppStore.cycle`, `CyclePlanner` (tâche 1), `AppStore.saveSession`, `SessionRoute`, `zoomSource`, le style de `NextSessionCard` (bandeau foncé, rayon 26).
- Produit : `CycleCard(zoom: Namespace.ID?, onOpenSession: (SessionRoute) -> Void, onEditCycle: () -> Void)` et `CyclePickerSheet(cycle: Cycle, nextId: String?, selection: Binding<String?>, onEditCycle: () -> Void)`.

**Quand elle s'affiche :**
- `CyclePlanner.offersCycle` est vrai pour moi et le cycle n'est pas vide.
- Elle prend la place du bandeau « Aucune séance prévue / Lancer une séance libre ». Si j'ai une séance prévue plus tard, son bandeau « Prochaine séance » reste, **sous** la carte du cycle.
- À la toute première ouverture (aucune séance), elle s'affiche au-dessus de la carte d'accueil, dont le bouton « Commencer une séance » devient un lien discret « Ou lancer une séance libre ».
- Si j'ai une séance en cours ou prévue aujourd'hui : pas de carte du cycle, l'accueil reste comme avant.

**Ce qu'on voit :**
- **Surtitre :** « Prochaine séance du cycle ».
- **Titre :** le nom de la séance type (« Pecs + bras »).
- **Ligne de détail :** « 7 exercices » et, s'il y a une dernière séance du cycle, « après Épaules + dos ».
- **Bouton principal**, pleine largeur, 52 pt : « Commencer avec Jules » (prénom de l'autre). Il crée les deux séances puis ouvre la mienne.
  - Si `partnerIsFree` est faux, ce bouton disparaît, « Commencer seul » devient le bouton principal, et une ligne dit « Jules a déjà une séance aujourd’hui. »
- **Deux actions secondaires** sur une ligne, 48 pt chacune : « Commencer seul » et « Une autre séance ».
- **« Une autre séance »** ouvre `CyclePickerSheet` (demi-hauteur) : la liste des séances types avec leur nombre d'exercices, la suivante marquée « Suivante », et une ligne « Modifier le cycle » (`onEditCycle`). Toucher une séance type la choisit pour la carte, **pour cette fois** ; le cycle ne change pas.
- **Séance sans exercice disponible** (point de vigilance 5) : rien n'est créé et la carte affiche « Cette séance n’a plus d’exercice. Modifie le cycle. »
- **Animation :** à l'apparition, la carte entre comme les autres cartes de l'accueil ; au changement de séance choisie, le titre passe en fondu.

**Création :** `CyclePlanner.sessions(for:target:me:partner:date: aujourd'hui, …)` avec `byId: store.exerciseById` (machines visibles), `saveSession` pour chacune, puis `onOpenSession(SessionRoute(id: la mienne, source: "cycle"))`.

- [ ] **Étape 1 : implémenter.** Dans `RootView`, `onEditCycle` ouvre les Réglages en attendant la tâche 3.
- [ ] **Étape 2 : vérifier sur simulateur** avec `-demo`, comme Clément puis comme Jules :
  1. La carte montre la séance suivante attendue d'après les données de démo.
  2. « Commencer avec Jules » : ma séance s'ouvre, en pyramide ; dans le Planning, deux séances aujourd'hui ; le fichier de démo montre le même `groupId`, le bon `cycleId`, et aucune charge de l'un chez l'autre.
  3. De retour sur l'accueil : la carte du cycle a laissé la place à ma séance du jour.
  4. Après avoir validé une série et terminé : la carte propose la séance type suivante.
  5. « Une autre séance » change le titre de la carte, sans changer le cycle.
  6. Première ouverture (sans `-demo`, fichier vide) : carte du cycle au-dessus de la carte d'accueil.
- [ ] **Étape 3 : commit** — `app: carte du cycle sur l'accueil`.

### Tâche 3 : « Mon cycle » dans les Réglages

**Fichiers :** créer `Settings/CycleSection.swift`, `Cycle/CycleTemplateEditor.swift` ; modifier `Settings/SettingsView.swift` (une ligne), `Navigation.swift` (`CycleRoute`), `RootView.swift` (destination, `onEditCycle`).

**Interfaces :**
- Consomme : `AppStore.cycle`, `saveCycle`, `ExercisePicker`, `ExerciseThumb`, le menu « … » de `PlanSpecCard`, `Stepper`.
- Produit : `CycleSection()`, `CycleTemplateEditor(templateId: String?)` (`nil` = nouvelle séance type), `struct CycleRoute: Hashable { var templateId: String? }`.

**Ce qu'on voit :**
- **Carte « Mon cycle »** dans les Réglages, après « Séance » :
  - le texte « Vos séances tournent dans cet ordre. L’accueil propose la suivante. » ;
  - une ligne par séance type : son rang, son nom, « 7 exercices », un chevron ; toucher la ligne ouvre l'éditeur ;
  - un menu « … » par ligne : « Monter », « Descendre », « Supprimer » (avec confirmation) ;
  - un bouton « Ajouter une séance ».
- **Éditeur** (écran poussé, même en-tête que l'éditeur de machine) :
  - « Nom » ;
  - la liste des exercices : vignette, nom, menu « … » (« Monter », « Descendre », « Retirer ») ; pour un exercice de cardio, un stepper « Minutes » par pas de 5, de 5 à 120 ;
  - « Ajouter des exercices » ouvre `ExercisePicker` ; un exercice déjà présent n'est pas ajouté deux fois ;
  - une ligne d'aide : « Les charges ne se règlent pas ici : chacun retrouve les siennes de la dernière fois. » ;
  - en bas : « Enregistrer », désactivé sans nom ou sans exercice. Quitter sans enregistrer abandonne les changements.
- **Supprimer une séance type** ne touche à aucune séance déjà faite.
- **Accès depuis l'accueil :** « Modifier le cycle » de `CyclePickerSheet` ouvre les Réglages sur la carte « Mon cycle ».

- [ ] **Étape 1 : implémenter.**
- [ ] **Étape 2 : vérifier sur simulateur.**
  1. Renommer « Cardio » en « Cardio long » : le nom change dans les Réglages et sur la carte de l'accueil.
  2. Retirer un exercice, en ajouter un, changer l'ordre : la prochaine séance créée depuis l'accueil les reprend.
  3. Passer « Machine à escalier » à 20 minutes : la séance créée a 20 minutes.
  4. Descendre « Épaules + dos » d'un rang : l'ordre du cycle change, la séance suivante se recalcule.
  5. Ajouter une quatrième séance, puis la supprimer : confirmation, retour à trois.
  6. Relancer l'appli : le cycle modifié est toujours là.
- [ ] **Étape 3 : commit** — `app: « Mon cycle » dans les Réglages`.

---

## À la fin de ce plan

- `cd ios/SuiviCore && swift test` : tous les tests passent.
- Sur l'accueil, la séance suivante du cycle se lance en un toucher, pour les deux ou pour soi.
- Version Release installée sur l'iPhone de Clément, sans lancement automatique.
- Reste pour la suite : la synchronisation entre les deux téléphones (plan 4), pour que Jules coche ses séances depuis son iPhone.
