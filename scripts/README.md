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
