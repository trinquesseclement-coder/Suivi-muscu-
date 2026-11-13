# Suivi Muscu iOS, plan 2 : ce qui reste et ce qui a été tranché

Le plan 2 (`2026-11-12-appli-ios-plan-2-planning-charge-machines.md`) est exécuté sur la branche `feat/appli-ios-plan-2`, commits `60bc733..c3c5c02`. Chaque tâche a été relue, puis toute la branche. Ce document garde ce que le journal d'exécution contenait et qui n'est pas dans le code : les décisions prises en cours de route et les défauts mineurs laissés pour plus tard.

État à la fin : 142 tests du paquet au vert, plus aucun onglet « Bientôt », version Release installée sur l'iPhone de Clément (sans lancement automatique).

## Décisions prises pendant l'exécution

Chacune peut être revue ; le coût indiqué est ce qu'il faudrait défaire.

| N° | Décision | Pourquoi | Coût si c'est faux |
|---|---|---|---|
| P1 | `PlanningView` reçoit la semaine affichée en `Binding`, détenue par `RootView`. | L'éditeur doit pouvoir revenir sur la semaine de la date choisie. | Un paramètre à retirer. |
| P2 | `BackupContent` porte `skipped` (éléments illisibles ignorés). | Le plan disait « ignorée et comptée » sans dire où. | Un champ en trop. |
| P3, révisé en R5 | Machines mémorise posture, aide et muscle. Le sélecteur d'exercices ne mémorise que la posture. La recherche n'est jamais mémorisée. | Le brief ne demande que le filtre fauteuil ; un muscle mémorisé coûte un toucher sur « Tout » à chaque ajout. | Aide et muscle à re-choisir à chaque ouverture du sélecteur. |
| P4 | `ExercisePicker(owner:)` renvoie toujours des exercices ; le schéma est choisi par `PlanBuilder`. | Le sélecteur ne construit pas de séance. | Paramètre peu utile. |
| P5 | Sur le vrai iPhone : une installation, aucun lancement automatique. | Les lancements répétés du plan 1 avaient dérangé l'utilisateur. | Pas de capture sur le vrai téléphone. |
| R1 | Chaque commit est signé du modèle qui l'a écrit (Sonnet, Opus ou Fable). | Attribution exacte plutôt qu'uniforme. | Des messages de commit à reformuler. |
| R2 | Dans le tableau de charge, tous les chiffres d'une semaine comptent les séries validées, même si la séance n'est pas terminée. Courbes et records ne lisent que les séances terminées. | Les graphiques d'une semaine restent d'accord entre eux et avec l'accueil. | Sans effet en pratique : une séance passe « terminée » dès la première série validée. |
| R3 | Photo de machine : on propose « Prendre une photo » et « Choisir dans la photothèque ». | Permet de reprendre une photo déjà prise. | Un menu de plus avant la prise de vue. |
| R4 | Toucher une séance dans le Planning l'ouvre toujours. La modification passe par le menu « … » de la séance. | Le plan ouvrait l'éditeur pour une séance prévue par soi : impossible de la démarrer depuis le Planning. | Un toucher de plus pour modifier une séance prévue. |
| R6 | Les petites images (32 Ko ou moins) se décodent tout de suite, sans attendre. | La photo de profil ne clignote plus au lancement. | Un léger à-coup à la première ouverture de Machines s'il y a plusieurs petites photos. |

## À faire avant ou pendant le plan 3 (icônes maison)

- **Composants en double à regrouper** avant de toucher aux icônes :
  - la barre flottante du bas existe en quatre exemplaires (`RootView`, `SessionView`, `PlanEditorParts`, `MachineEditor`) ;
  - le bouton retour rond, l'en-tête de feuille, `field()` et les libellés de posture sont répétés ;
  - `WhoPicker` est devenu le contrôle segmenté de toute l'appli : le renommer et le déplacer dans `Design/`.
- **Couleurs en dur restantes** : quelques `Color.white.opacity(…)` dans le Planning et l'éditeur de plan, à passer en jetons `Theme`.
- **Décodage immédiat des images** : le limiter aux photos de profil, pas seulement par la taille (`Design/DataURLImage.swift`).
- **Libellés d'aide** : le sélecteur écrit « Aide » sur ses lignes et « Avec Jules » sur sa pastille ; Machines écrit « Aide Jules ».
- **Fiche machine** : une photo en portrait laisse des bandes vides à gauche et à droite ; la photo saute du gabarit à sa vraie proportion à la première ouverture.
- **Planning** : seule la semaine entrante glisse, la sortante s'efface ; la ligne compacte d'un jour vide n'est pas annoncée comme titre par VoiceOver.
- **Sauvegarde** : le message de résultat reste affiché jusqu'au prochain import ; en très grand texte le message d'erreur passe un mot par ligne ; un fichier iCloud non téléchargé est annoncé « pas une sauvegarde ».

## À faire avant le plan 4 (synchro Supabase, TestFlight)

- **Écriture du fichier de données sur le fil principal** à chaque appui sur un stepper. Mesuré sur le Mac : 18 ms pour 300 séances, 60 ms pour 800 séances et 70 photos. Pas gênant aujourd'hui ; à déplacer hors du fil principal ou à regrouper avant un an d'historique.
- **`saveExercise` enregistre la machine entière**, ce qui fige les valeurs du catalogue pour une machine photographiée ou annotée. N'enregistrer que les différences. Même remarque pour l'export.
- **Une sauvegarde ne ressuscite pas une séance supprimée par erreur** : la suppression locale est plus récente, donc elle gagne. À dire dans le résumé, ou proposer de restaurer.
- **Import d'un export web fait en mode Supabase** : les séances y ont des identifiants de profil différents et n'apparaîtraient pas. Hors périmètre tant que le web tourne en mode local.
- **Restauration du profil** : l'import ne reprend pas le prénom ni « a besoin d'aide » sur un téléphone neuf.
- **Paire « pour les deux »** : changer le propriétaire ou la date d'une des deux séances peut laisser deux séances du même groupe chez la même personne. Rien ne lit ce lien sur iOS pour l'instant.
- **Liste des champs d'une machine répétée cinq fois** dans `ExerciseOverride` : ajouter un test aller-retour avec tous les champs remplis avant d'en ajouter un.

## Comportements à connaître, laissés tels quels

- **Modifications non enregistrées** : quitter l'éditeur de plan ou l'éditeur de machine par le bouton retour ou le balayage les abandonne sans avertir. « Reprendre une séance » remplace les exercices déjà ajoutés.
- **Modifier une séance prévue l'aplatit** : en classique les séries deviennent identiques, et les notes par exercice sont perdues, même pour un simple changement de date.
- **Photos de moins de 200 px** : refusées comme illisibles.
- **Avec « Avec Jules » allumé**, les heures ne sont plus écrites au-dessus des barres, trop étroites ; elles restent dans « Voir le tableau ».

## Non vérifié sur le vrai iPhone

La vérification visuelle a été faite au simulateur (iPhone Duo, format pliable). Restent à voir sur le téléphone :

- prendre une photo de machine avec le vrai appareil photo, y compris pendant un chrono de repos ;
- exporter par AirDrop deux fois de suite, puis annuler le sélecteur de fichier à l'import ;
- changer de personne dans le tableau de charge, avec et sans « Réduire les animations » ;
- la largeur réelle de 390 pt sur chaque nouvel écran.
