# Suivi Muscu iOS, « Mon cycle » : ce qui reste et ce qui a été tranché

Le plan `2026-11-12-appli-ios-cycle.md` est exécuté sur la branche `feat/appli-ios-cycle` (partie de `feat/appli-ios-plan-2`), commits `8ad3d10..eb100ee`. Chaque tâche a été relue, puis toute la branche. État à la fin : 177 tests du paquet au vert, version Release installée sur l'iPhone de Clément, sans lancement automatique.

## Décisions prises pendant l'exécution

| N° | Décision | Pourquoi | Coût si c'est faux |
|---|---|---|---|
| R1 | En pyramide, les charges sont reprises série par série de la dernière pyramide, cochées ou non. La 4e retombe sur la 1re s'il n'y en avait que trois. | Avant, une seule série non cochée remettait les quatre à 0 kg. | Une charge prévue mais pas faite est reproposée. |
| R2 | Chaque exercice est recréé avec la façon de faire (pyramide ou classique) de la dernière fois, quand elle a été enregistrée par l'appli iOS. Sinon, la façon par défaut du profil. Vaut partout : cycle, planning, ajout en séance, copie. | « Comme la dernière fois » vaut aussi pour la façon de faire (les abdos en classique, par exemple). | Un exercice passé une fois en classique le reste jusqu'à ce qu'on le rebascule. |
| R3 | Une séance du cycle est construite de la même façon qu'on commence seul ou à deux : à partir de la dernière fois de la personne, série par série. | Commencer seul aplatissait un historique classique en « n séries à la charge la plus lourde ». | Aucun attendu. |
| R4 | En créant les séances du jour, on supprime les séances du cycle des jours passés jamais commencées des personnes concernées. | Sur un seul téléphone, chaque « Commencer avec Jules » laissait une séance « prévue » de Jules dans le Planning. | Une séance du cycle préparée puis laissée de côté disparaît le jour où on en lance une autre. |
| R5 | « Copier dans mes séances » garde le lien avec le cycle. | Faire la copie fait avancer son cycle. | Une copie d'une séance du cycle compte comme une séance du cycle. |
| R6 | Pyramide précédente d'une ou deux séries seulement : la série manquante prend la charge de la précédente. | Même règle que le passage classique → pyramide. | Charges de départ approximatives dans ce cas rare. |
| — | Les Réglages sont devenus un écran « poussé » comme les autres (une route), avec une garde contre la double ouverture. | L'éditeur du cycle ne s'ouvrait pas depuis les Réglages avec l'ancien montage. | Rien de visible. |

## Comportements à connaître

- **Première séance de chaque type : les charges partent de 0 kg.** L'appli n'a pas encore d'historique. Toucher le chiffre permet de le taper ; à la séance suivante du même type, elles reviennent.
- **Jules sur le même téléphone.** « Commencer avec Jules » crée sa séance, mais il ne peut la cocher qu'en passant sur son profil dans les Réglages. Tant que la synchronisation (plan 4) n'existe pas, sa séance reste « prévue » ; elle est nettoyée au prochain lancement (R4).
- **Le cycle avance sur ce qui a été fait** : une séance du cycle sans aucune série cochée ne compte pas.
- **Les minutes de cardio** viennent toujours de la séance type, pas de la dernière fois.
- **Si l'autre a déjà une séance aujourd'hui**, « Commencer avec … » disparaît ; si ça change entre l'affichage et le toucher, seule la sienne est créée, sans message.

## Laissé pour plus tard

- **Éditeur de plan** : en classique pour une seule personne, il aplatit encore l'historique en « n séries à la charge la plus lourde », alors que le cycle le reprend série par série (`PlanBuilder.spec`).
- **Ajout du même exercice deux fois dans une séance en cours** : la « dernière fois » n'exclut pas la séance en cours (`SessionView.addExercises`).
- **Retour hors écran** : ouverts depuis l'accueil sur « Mon cycle », les Réglages ont leur bouton retour hors de l'écran (le balayage marche).
- **En très grand texte**, l'icône « … » des lignes du cycle dépasse son cadre.
- **Code en double** : l'en-tête et les champs de l'éditeur du cycle sont copiés de l'éditeur de machine (troisième copie) ; l'éditeur de machine garde le défaut « la touche OK ajoute un retour à la ligne au nom ».
- **Le sélecteur d'exercices** ne marque pas ceux déjà présents dans la séance type (ils sont ignorés à l'ajout).
- **Sauvegarde** : un import qui ne prend pas le cycle du fichier (le téléphone en a déjà un) ne le dit pas. L'argument de test `-import-file` n'a pas été relancé depuis le changement de navigation : refaire un export puis un import au simulateur.
- **Minuit** : si minuit passe pendant qu'on regarde l'accueil, la carte ne se recalcule qu'au toucher ou au retour dans l'appli.
- **Plan 4 (synchro)** : en mode Supabase, le web n'envoie pas le lien avec le cycle (`cycleId`) ; à prévoir dans le schéma.
- **Fil de l'accueil** : deux séances du cycle faites à deux s'affichent l'une sous l'autre avec leur tonnage. À regarder au regard de la règle « ne jamais comparer les charges ».
