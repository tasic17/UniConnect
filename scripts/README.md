# Firebase Admin skripte

## Migracija followers mirror-a

Popunjava `users/{targetId}/followers/{followerId}` za sve postojeće `following` zapise.

### Preduslov

1. U [Firebase Console](https://console.firebase.google.com) → Project Settings → Service accounts → **Generate new private key**
2. Sačuvaj JSON kao `scripts/service-account.json` (fajl je u `.gitignore` — ne commituj ga)

### Pokretanje

```bash
cd scripts
npm install
export GOOGLE_APPLICATION_CREDENTIALS="./service-account.json"
npm run migrate:followers
```

### Automatska migracija u aplikaciji

Pri svakoj prijavi aplikacija pokreće migraciju **za tog korisnika** (njegova `following` lista → `followers` kod drugih). To je dovoljno za aktivne naloge; admin skripta odmah popravlja celu bazu.

## Admin nalog (`admin@gmail.com`)

Kreira Auth korisnika i Firestore `users/{uid}` sa `role: "admin"` i `emailVerified: true`.

### Produkcija (service account)

```bash
cd scripts
npm install
export GOOGLE_APPLICATION_CREDENTIALS="./service-account.json"
npm run create:admin
```

### Emulator

Pokreni Auth + Firestore emulator, zatim:

```bash
export GCLOUD_PROJECT="uniconnect-e2a78"
export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
npm run create:admin
```

**Podrazumevani podaci:** `admin@gmail.com` / `admin123` — samo za razvoj/diplomu; u produkciji koristi jaku lozinku.

Posle kreiranja deploy-uj Firestore rules:

```bash
firebase deploy --only firestore:rules
```
