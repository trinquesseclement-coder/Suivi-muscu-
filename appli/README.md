# Suivi Muscu

Appli de suivi de séances à deux (Clément & Jules), installable sur le téléphone.

- **Accueil** : prochaine séance, ce que l'autre est en train de faire (« En cours »), le bilan de la semaine de chacun, le fil des dernières séances avec les records battus.
- **Planning** : semaine par semaine, on planifie pour soi, pour l'autre ou pour les deux d'un coup (chacun avec ses propres charges).
- **Séance en direct** : gros boutons −/+ pour les kilos et les reps, une case pour valider chaque série, minuteur de repos, rappel de la dernière fois, trophée quand un record tombe. Le cardio se note en minutes / distance / niveau.
- **Tableau de charge** : tonnage par semaine, minutes de cardio, séries par muscle, progression par machine (charge max, 1RM estimé, tonnage) et records. Chaque graphique a sa vue « tableau ».
- **Machines** : ~70 exercices pour une salle très équipée. Chacun est marqué :
  - *Fauteuil* (faisable sans quitter le fauteuil), *Transfert* (s'installer sur le siège) ou *Debout* ;
  - *Aide Jules* quand il faut charger des disques ou installer.

  On filtre là-dessus, et tout se corrige (posture, aide, réglages du siège en note) : la correction est partagée entre vous deux.

## Lancer en local

```bash
cd appli
npm install
npm run dev
```

Sans configuration, l'appli tourne en **mode local** : les deux profils sont sur le même téléphone (on bascule dans Réglages). Pratique pour tester.

## Mettre en ligne (Netlify + Supabase)

Netlify héberge l'appli, Supabase garde les données partagées et gère les comptes.

### 1. Supabase (la base de données)

1. Crée un projet sur [supabase.com](https://supabase.com) (offre gratuite).
2. **SQL Editor** → *New query* → colle le contenu de [`supabase/schema.sql`](supabase/schema.sql) → *Run*.
3. **Authentication → Sign In / Providers → Email** : désactive *Confirm email* (sinon il faut cliquer le lien reçu avant de se connecter).
4. **Project Settings → API** : note la *Project URL* et la clé *anon* / *publishable*. Elle est publique par nature : c'est la sécurité de la base (RLS) qui protège les données.

### 2. Netlify (l'hébergement)

1. *Add new site → Import from Git* → ce dépôt. Le fichier `netlify.toml` à la racine règle tout (dossier `appli`, build, publication).
2. *Site configuration → Environment variables* :
   - `VITE_SUPABASE_URL` = la Project URL
   - `VITE_SUPABASE_ANON_KEY` = la clé anon
3. Redéploie.

La fonction `netlify/functions/keepalive.mjs` interroge la base chaque jour : Supabase met en pause les projets gratuits après 7 jours sans activité (vacances, blessure…), ça l'évite.

### 3. Créer vos deux comptes

Chacun ouvre le site sur son téléphone → *Créer un compte* → prénom. Ensuite :

- **Verrouille l'accès** : *Authentication → Sign In / Providers* → désactive *Allow new users to sign up*. Plus personne d'autre ne peut créer de compte.
- **Installe l'appli** : Safari → Partager → *Sur l'écran d'accueil* (iPhone), ou Chrome → menu → *Installer l'application* (Android).

## Comment marche la synchro

- Tout est d'abord enregistré **sur le téléphone** : l'appli marche sans réseau au fond de la salle. Les modifs partent dès que le réseau revient (pastille *Synchro* / *Hors ligne* en haut de l'accueil).
- Les séances de l'autre arrivent **en temps réel**, avec une vérification toutes les 30 s en secours.
- Droits : chacun voit tout. On ne modifie que ses propres séances, sauf les séances **prévues** : on peut planifier pour l'autre et retoucher ce qu'on a planifié tant que ce n'est pas commencé.
- **Réglages → Sauvegarde** exporte toutes les données dans un fichier JSON.

## Structure

```
appli/
  src/
    data/exercises.ts   catalogue des machines (posture, aide, pas des +/−)
    lib/store.ts        stockage local + file d'attente + synchro Supabase
    lib/stats.ts        tonnage, 1RM estimé (Epley), records, stats hebdo
    pages/              Accueil, Planning, Séance, Tableau de charge, Machines, Réglages
    components/         graphiques SVG, sélecteur d'exercices, UI
  supabase/schema.sql   tables + règles d'accès + temps réel
  netlify/functions/    keep-alive de la base
```

Stack : React 19 + TypeScript + Vite, PWA (vite-plugin-pwa), Supabase. Thème « sauge » en verre dépoli, police Poppins (embarquée, marche hors ligne).
