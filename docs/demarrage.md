# Demain matin : mettre l'appli dans ta poche

Deux chemins. **Choisis A si tu as 3 minutes, B si tu as 15 minutes.** Tu peux faire A demain matin et B plus tard : rien ne sera perdu, l'appli reprend tes séances quand tu passes en ligne.

---

## A. Version express (3 min) : ton téléphone seul

L'appli marche tout de suite, hors ligne, mais Jules ne voit pas tes séances.

- [ ] Va sur **app.netlify.com** → connecte-toi avec GitHub.
- [ ] **Add new project** → **Import an existing project** → **GitHub** → choisis le dépôt **Suivi-muscu-**.
- [ ] **Branche à déployer : `claude/stoic-brown-klizpg`**. C'est la seule branche du dépôt ; il n'y a pas de `main`.
- [ ] Ne touche à rien d'autre : le fichier `netlify.toml` règle le dossier et la commande de build. → **Deploy**.
- [ ] Au bout d'environ 1 minute, Netlify te donne une adresse en `….netlify.app`. Tu peux la renommer dans *Project configuration → Change project name*, par exemple `muscu-komex`.
- [ ] Sur ton iPhone, ouvre l'adresse **dans Safari** (pas Chrome) → bouton Partager → **Sur l'écran d'accueil**.

C'est tout. Ouvre l'appli depuis l'icône, pas depuis Safari.

---

## B. Version complète (15 min) : toi et Jules, synchronisés

Fais d'abord A, puis :

### 1. La base Supabase (5 min)
- [ ] **supabase.com** → *Start your project* → connecte-toi avec GitHub.
- [ ] **New project** : nom `suivi-muscu`. Choisis un mot de passe de base (note-le quelque part, il ne sert presque jamais), région **West EU (Paris)**.
- [ ] Attends environ 1 minute que le projet soit prêt.
- [ ] **SQL Editor** → *New query* → colle **tout** le fichier `appli/supabase/schema.sql` du dépôt → **Run**. Le message « Success » doit s'afficher.
- [ ] **Authentication → Sign In / Providers → Email** : **décoche « Confirm email »** → Save.
- [ ] **Project Settings → API Keys** : copie la **Project URL** et la clé **publishable** (ou *anon*). Elle est publique par nature : ce sont les règles de la base qui protègent les données.

### 2. Brancher Netlify sur Supabase (2 min)
- [ ] Netlify → ton projet → **Project configuration → Environment variables** → *Add a variable* :
  - `VITE_SUPABASE_URL` = la Project URL
  - `VITE_SUPABASE_ANON_KEY` = la clé
- [ ] **Deploys → Trigger deploy → Deploy project**.
- [ ] Sur ton iPhone : ferme l'appli complètement (balayer vers le haut), rouvre-la. Si l'écran de connexion n'apparaît pas, ferme et rouvre encore une fois : la nouvelle version s'installe au premier lancement.

### 3. Vos deux comptes (3 min)
- [ ] **Toi** : *Créer un compte* (email + mot de passe). Si tu avais déjà noté des séances en mode A, elles passent automatiquement sur ton compte.
- [ ] **Jules** : envoie-lui l'adresse. Il l'ouvre dans Safari (ou Chrome sur Android), l'ajoute à l'écran d'accueil et crée son compte.
- [ ] **Ferme les inscriptions** : Supabase → *Authentication → Sign In / Providers* → décoche **« Allow new users to sign up »**. Plus personne d'autre ne pourra créer de compte.
- [ ] Chacun ajoute sa photo : Réglages → touche le rond à côté de ton prénom.

### Si Jules a noté des séances sur ton téléphone en mode A
Réglages → carte **« Séances de Jules sur ce téléphone »** → *Exporter pour Jules* → envoie-lui le fichier (AirDrop, WhatsApp…). Sur son téléphone : Réglages → Sauvegarde → **Importer**.

---

## À la salle, pour la première séance

- **Lance « Séance libre »** et ajoute tes machines au fur et à mesure. Garde le filtre **« Depuis le fauteuil »** : il reste actif d'une fois sur l'autre.
- **La première fois, les charges sont à 0.** C'est normal : il n'y a pas encore de « dernière fois ». Dès la 2e séance, tout est pré-rempli. Change la série 1 : les suivantes suivent.
- **Note les réglages des machines** quand tu les trouves (Machines → la machine → Note : « siège cran 4 »). Ils s'afficheront en séance la prochaine fois.
- **Corrige la marque ou la posture** d'une machine si ce que j'ai deviné est faux (Machines → la machine).
- **Masque les machines que KOMEX n'a pas** : Machines → la machine → *Masquer*. Moins de choix, moins de friction.

### À vérifier sur ton iPhone, je ne peux pas le tester d'ici
- [ ] **L'écran reste allumé** pendant la séance (iOS 18.4 ou plus récent).
- [ ] **Le bip de fin de repos** s'entend : coupe le mode silencieux pour tester. Réglages → « Bip à la fin du repos » joue un bip d'essai.
- [ ] **Sans réseau au sous-sol** : la pastille passe en « Hors ligne », puis en « Synchro » quand tu remontes.

Si quelque chose cloche, fais une capture d'écran et envoie-la moi.
