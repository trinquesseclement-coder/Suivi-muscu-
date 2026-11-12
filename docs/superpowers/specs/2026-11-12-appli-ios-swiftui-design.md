# Suivi Muscu iOS : brief de l'appli SwiftUI

12 novembre 2026 · statut : **brouillon, à valider par Clément**

## 1. L'intention

Clément et Jules s'entraînent ensemble à KOMEX (Dijon). Clément est en fauteuil ; Jules l'aide à charger les disques sur certaines machines. Ils ont déjà une appli web (PWA) dans `appli/` : séances notées à deux, planning partagé, tableau de charge, catalogue des machines de la salle. Elle n'a jamais été mise en ligne.

Clément veut une **appli iPhone native, entièrement réécrite en SwiftUI**, qui reprend tout ce que fait l'appli web et ajoute :

- un **tableau de bord à l'ouverture**, qui montre tout de suite combien de séances chacun a faites cette semaine et combien d'heures ça représente ;
- **sa façon de s'entraîner** : la pyramide 12 / 10 / 8 / 12 ;
- une appli **vivante** : motion design, barres animées, transitions fluides ;
- une identité à elle : **logo KOMEX**, **photo de profil**, **icônes faites maison** dessinées dans VectorCraft.

Les deux ont un iPhone. **Le partage entre les deux téléphones reste** : chacun voit les séances de l'autre, et on peut planifier pour l'autre.

## 2. Objectifs

1. Installer l'appli sur l'iPhone 14 de Clément (branché au Mac), puis sur l'iPhone de Jules.
2. Faire tout ce que fait l'appli web (liste au §5), en SwiftUI natif.
3. Le tableau de bord B comme écran d'accueil (§6).
4. La pyramide 12/10/8/12 intégrée à la saisie des séries (§7).
5. Des animations partout où elles aident à comprendre ou récompensent (§8).
6. Les données des deux téléphones restent synchronisées, et l'appli marche sans réseau au fond de la salle.

## 3. Hors périmètre (v1)

- Pas de publication sur l'App Store : appli privée pour deux personnes.
- Pas d'Apple Watch, pas de widgets, pas de Siri.
- Pas de nouvelles fonctions au-delà de celles listées ici. L'audit du 11/11 dit déjà que l'appli en a trop à la périphérie.
- Pas de version Android.

## 4. Ce qui ferait de l'appli un échec, même si elle « marche »

- **Une animation qui ralentit la saisie.** Entre deux séries, d'une seule main, chaque appui compte. Aucune animation ne doit bloquer un bouton ni faire attendre.
- **Un effet gadget qui fatigue** : tout qui bouge en même temps, des rebonds permanents, des confettis partout.
- **Perdre une série** parce que le réseau a coupé.
- **Comparer les charges de Clément et de Jules côte à côte.** L'audit le déconseille à l'unanimité. Le tableau de bord compare *des séances et des heures*, jamais des kilos.
- **Une appli qui ne marche que branchée au Mac**, ou qui s'arrête sans prévenir (voir §11, installation).

## 5. Périmètre : reprendre l'appli web

Le code web sert de référence fonctionnelle : `appli/src/`, environ 3 600 lignes de TypeScript/React. Le builder s'y réfère pour les comportements exacts. Les 15 écrans capturés sont dans la planche de maquette de la session (`maquette/index.html` dans le dossier de travail). On peut les regénérer avec le serveur de dev.

| Écran web | Fichier | À reprendre |
|---|---|---|
| Accueil | `pages/Home.tsx` | remplacé par le tableau de bord B (§6), avec le fil des dernières séances en dessous |
| Planning | `pages/Planning.tsx` | semaine par semaine, « Planifier » pour soi, l'autre ou les deux |
| Préparer une séance | `pages/PlanEditor.tsx` | à l'identique |
| Séance en direct | `pages/SessionPage.tsx` | à l'identique, plus la pyramide (§7) et les animations (§8) |
| Tableau de charge | `pages/Stats.tsx`, `components/Charts.tsx` | à l'identique, avec Swift Charts, animé |
| Machines | `pages/Machines.tsx`, `data/exercises.ts`, `data/gym.ts` | les ~70 exercices : posture (fauteuil / transfert / debout), aide, marque, note de réglage, photo de la machine |
| Réglages | `pages/Settings.tsx` | profils, photo, « a besoin d'aide », salle, séance, synchro, sauvegarde |
| Connexion | `pages/Auth.tsx` | e-mail + mot de passe (Supabase) |

À conserver, déjà corrigé côté web (audit P1, `docs/audit-2026-11-11.md`) :
- l'écran reste allumé pendant la séance ;
- une alerte prévient de la fin du repos ;
- le libellé d'aide est dans le bon sens sur chaque téléphone ;
- la note de réglage de la machine s'affiche en séance ;
- un bouton explicite pour valider la série ;
- le filtre fauteuil reste actif d'une fois sur l'autre.

Les illustrations des mouvements viennent de free-exercise-db (GitHub), comme sur le web. Elles sont chargées puis gardées en cache, pas copiées dans l'appli (voir `appli/README.md` pour l'origine des images).

## 6. L'écran d'accueil : le tableau de bord B

Maquette validée : `.superpowers/brainstorm/…/content/dashboard-v3.html`, option **B**.

De haut en bas :

1. **En-tête** : le logo KOMEX à gauche (SVG blanc récupéré sur komex-gymclub.fr, `logo-komex.svg`), la **photo de profil** de la personne connectée à droite. Toucher la photo ouvre les Réglages.
2. **« Cette semaine »** : deux cartes côte à côte, **moi à gauche**, l'autre à droite. Chaque carte a :
   - sa couleur : Clément en vert, Jules en orange (le champ `slot` existant) ;
   - un **anneau** qui se remplit vers l'**objectif** de séances de la semaine, avec « 3 sur 4 » au centre ;
   - le **temps total** de la semaine, avec une icône (« 2h45 »).
3. **Bloc « Ensemble »** : le nombre de séances faites le même jour par les deux, et le total d'heures des deux.
4. **La prochaine séance**, avec un bouton pour la lancer.
5. Plus bas, en faisant défiler : le fil des dernières séances, comme sur le web.

Règles de calcul (choix de Claude, modifiables) :
- **La semaine** va du lundi au dimanche et repart à zéro chaque lundi.
- **La durée d'une séance** :
  - si la durée a été saisie ou corrigée au bouton « Terminer » (`durationMin`, plafond de 240 min comme sur le web), c'est elle qui compte ;
  - sinon, elle va de la première série cochée au bouton « Terminer », plafonnée à 2 h 30 pour ne pas compter une séance fantôme de 14 heures ;
  - une séance sans aucune série cochée compte pour 0.
- **Une séance compte** dès qu'au moins une série ou un cardio est validé.
- **L'objectif** est réglable par chacun dans les Réglages, **3 séances par semaine par défaut**. Quand il est atteint, l'anneau change de couleur et il y a une petite célébration (§8).
- **« Ensemble »** compte les jours où les deux ont une séance qui compte.

## 7. La pyramide 12 / 10 / 8 / 12

Validée telle quelle par Clément :

- 4 séries : **12 répétitions légères (chauffe)**, **10 un peu plus lourd**, **8 très dur (le plus lourd)**, **12 en revenant à la charge de la série 1**.
- Quand on ajoute un exercice de muscu, il arrive avec ces 4 séries et ces répétitions.
- Les charges reprennent celles de la dernière fois, **série par série**. Le rappel « Dernière fois : 20×12 · 25×10 · 30×8 · 20×12 » reste affiché.
- **Changer la charge de la série 1 met à jour la série 4.** Les séries 2 et 3 restent indépendantes. C'est différent du web, où la série 1 est recopiée dans toutes les séries suivantes.
- C'est le **schéma par défaut**, pas une obligation. On peut passer un exercice en « séries classiques » : n séries avec les mêmes répétitions et la même charge, la série 1 recopiée dans les suivantes comme sur le web.
- Le schéma par défaut est **un réglage par personne** : Clément est en pyramide, Jules choisit le sien. Le cardio ne change pas.

## 8. Motion design

La demande de Clément : « des animations de barres, que ce soit vivant ». Les principes : **rapide (350 ms au plus), jamais bloquant, toujours utile**. Tout passe par les animations natives de SwiftUI : ressorts (springs), `contentTransition(.numericText)`, `matchedGeometryEffect`, `phaseAnimator`, `symbolEffect` pour les icônes, animations de Swift Charts. Le réglage **« Réduire les animations »** de l'iPhone remplace les mouvements par de simples fondus.

Liste prévue (proposition de Claude) :

| Moment | Animation |
|---|---|
| Ouverture de l'appli, retour à l'accueil | les anneaux se remplissent depuis 0, les chiffres défilent jusqu'à leur valeur, les deux cartes apparaissent l'une après l'autre |
| Objectif atteint | l'anneau change de couleur, une courte pulsation, une vibration |
| Tableau de charge | les barres poussent depuis le bas l'une après l'autre ; changer de machine ou de mesure fait glisser les barres vers leur nouvelle hauteur |
| Valider une série | la coche « saute », une vibration légère, la ligne passe au vert |
| Record battu | un trophée animé avec de petites particules et une vibration plus forte, une seule fois par record |
| Minuteur de repos | un compte à rebours circulaire ; pulsation et vibration sur les 3 dernières secondes ; un son à la fin |
| Passer d'une carte de séance à la séance | la carte s'agrandit jusqu'à devenir l'écran |
| Changer une charge | le chiffre défile au lieu de sauter |
| Barre d'onglets | l'icône de l'onglet choisi bouge légèrement |
| Synchro | la pastille « Synchro / Hors ligne » change en douceur |

## 9. Les icônes

- Clément veut **ses propres icônes**, dessinées dans **VectorCraft** (l'outil de dessin vectoriel dont dispose Claude), pas les SF Symbols d'Apple.
- Un même style pour toutes : trait épais, coins arrondis, lisibles à 20 px, une seule couleur qui prend celle du thème.
- Inventaire proposé (~22 icônes) :
  - navigation : accueil, planning, ajouter, charge, machines, réglages ;
  - chiffres : séances, temps / chrono, minuteur de repos, trophée / record, objectif ;
  - postures et aide : fauteuil, transfert, debout, aide (main) ;
  - matériel : disque / haltère, cardio ;
  - divers : synchro, hors ligne, photo, pyramide, ensemble (2 personnes).
- Le circuit :
  1. Claude les dessine dans VectorCraft.
  2. Clément les valide ou les retouche.
  3. Export en SVG.
  4. Intégration dans le catalogue d'images d'Xcode en mode *template*, pour qu'elles prennent la couleur voulue. Ou en SF Symbols personnalisés si les animations l'exigent.
- Le logo KOMEX est utilisé tel quel (version blanche sur fond sombre). L'icône de l'appli reste à dessiner (§12).

## 10. Choix techniques

Déjà décidé :
- **SwiftUI**, appli iOS native : un nouveau projet Xcode dans le même dépôt (dossier `ios/`), à côté de `appli/`.
- **Partage via Supabase**, avec le **même schéma** que le web (`appli/supabase/schema.sql` : tables `profiles`, `sessions`, `exercises`, et leurs règles d'accès RLS).
- **Local d'abord** : tout est enregistré sur le téléphone. Une file d'attente envoie les modifs dès que le réseau revient. Les séances de l'autre arrivent en temps réel. C'est la même logique que `appli/src/lib/store.ts`.

Choix de Claude (le builder peut les revoir si une raison technique l'impose) :
- Le client officiel `supabase-swift`.
- Le stockage local : fichier JSON ou SwiftData, au choix du builder.
- Les graphiques : Swift Charts.
- **L'appli web devient une référence, pas une appli utilisée en parallèle**, puisque les deux ont un iPhone. On ne la modifie pas.
  - Conséquence acceptée : si quelqu'un l'utilisait quand même, elle pourrait effacer les nouveaux champs. `sessionToRow` dans `store.ts` ne réécrit que ses propres champs.
- Les nouveaux champs :
  - par exercice d'une séance (mode « pyramide / classique ») : dans le JSON `items` déjà stocké dans `sessions.data` ;
  - par profil (schéma par défaut, objectif de la semaine) : la table `profiles` n'a pas de colonne JSON. On ajoute une colonne `settings jsonb default '{}'` par un script SQL qu'on peut relancer sans risque, ajouté à `appli/supabase/schema.sql`.
- L'écran reste allumé pendant la séance (`isIdleTimerDisabled`). La fin du repos déclenche une notification locale si l'appli est en arrière-plan.
- **Supabase gratuit se met en pause après 7 jours sans activité.** La fonction Netlify `keepalive`, jamais déployée, est remplacée par une tâche planifiée GitHub Actions dans le dépôt, qui interroge la base une fois par jour.

## 11. Installation sur les téléphones

- Côté Mac : Xcode 27.2, une identité de signature « Apple Development », et **l'iPhone 14 de Clément détecté et appairé**.
- **Compte Apple : programme développeur payant** (réponse de Clément).
- Clément : on compile et on installe directement depuis le Mac, par câble, pendant le développement.
- Jules : **TestFlight**. Il installe l'appli de chez lui, et chaque build tient 90 jours.
- **Version minimale : iOS 18.** Jules a un iPhone 12 ou plus récent, et Clément un iPhone 14.

## 12. Laissé au builder

- L'architecture du code Swift, le découpage en dossiers, les tests.
- Les durées et courbes exactes des animations, dans les principes du §8.
- L'icône de l'appli : une proposition à partir du « K » de KOMEX ou un dessin dédié, à montrer à Clément.
- La reprise de données saisies côté web, s'il y en a. L'appli web n'a jamais été en ligne, donc a priori rien à reprendre.

## 13. Décisions de Clément sur les questions ouvertes (12/11)

1. **Compte Apple** : payant, donc TestFlight pour Jules (§11).
2. **iPhone de Jules** : iPhone 12 ou plus récent, donc iOS 18 minimum.
3. **Supabase : plus tard.** La v1 se construit d'abord **en local sur le téléphone de Clément**, comme le mode local du web : les deux profils sont sur le même appareil, et on bascule de l'un à l'autre dans les Réglages.
   - La couche de synchro doit pouvoir se brancher ensuite sans tout réécrire : même schéma, même file d'attente.
   - Le jour venu, Clément crée le projet Supabase (guide : `docs/demarrage.md`, partie B), et Claude fournit le script SQL.
   - Le partage reste un objectif du projet : il est seulement décalé.
