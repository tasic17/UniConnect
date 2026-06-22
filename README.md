# UniConnect

iOS aplikacija za **studentski kampus** — događaji, oglasi, feed objave, poruke, praćenje korisnika i profil. Projekat je pisan u **SwiftUI** uz arhitekturu **MVVM** i backend **Firebase** (Auth, Cloud Firestore, Storage).

## Tehnologije

| Oblast | Izbor |
|--------|--------|
| Jezik | Swift 5.9+ |
| UI | SwiftUI |
| Arhitektura | MVVM (`View` + `ViewModel` + `Service`) |
| Backend | Firebase Auth, Cloud Firestore, Firebase Storage |
| Mape | MapKit, geokodiranje adresa (`GeocodingHelper`) |
| Slike | `PhotosUI`, kompresija (`ImageCompression`), upload u Storage |

Minimalna verzija iOS-a: **iOS 17+**.

## Funkcionalnosti

### Gotovo

- **Autentifikacija** — prijava, registracija, odjava; **zaboravljena lozinka** (Firebase reset email); dokument korisnika u `users/{uid}`; verifikacioni email pri registraciji.
- **Događaji** — lista i mapa, filter po kategoriji, kreiranje (adresa → koordinate), detalj, RSVP, izmena/brisanje za organizatora; navigacija na profil organizatora.
- **Oglasi** — lista, pretraga, filter kategorije, kreiranje sa slikama, detalj, izmena slika, brisanje; autor vidljiv u detalju oglasa; kontakt prodavca preko poruka.
- **Feed** — korenske objave, threadovi (odgovori), lajkovi, slike, brisanje thread-a; filter **Praćeni** / **Svi**; pretraga korisnika (lupa); navigacija na profil (avatar + ime).
- **Praćenje** — zaprati / otprati, liste **Pratioci** i **Pratiš** na profilu (sveže ime/slika iz `users/{uid}`), pretraga svih korisnika, novo ćaskanje samo sa praćenima; sync mirror zapisa pri izmeni profila.
- **Profil** — pregled i izmena (ime, godina, smer, bio, profilna slika); tuđi profil; sekcije oglasa i feed objava autora.
- **Poruke** — tab sa badge-om nepročitanih; sekcije **Razgovori** i **Oglasi**; real-time chat (Firestore); tekst i **slike**; brisanje razgovora; DM sa profila; chat sa oglasa; uvek svež avatar/ime sagovornika.
- **Performanse** — paralelno učitavanje tabova, Firestore disk keš, `URLCache`, `AuthorProfileCache` za autore i učesnike chata.

### U planu

- Read receipts (označavanje pojedinačnih poruka kao pročitanih)
- Push notifikacije za nove poruke
- Paginacija feeda / oglasa
- Globalna pretraga (oglasi + događaji + korisnici)

## Struktura repozitorijuma

```
UniConnect/
├── firebase.json
├── firestore.rules
├── firestore.indexes.json   # Collection group indeksi (follow sync)
├── storage.rules
├── scripts/                 # Admin skripte (opciono)
│   └── migrate-followers-mirror.mjs
├── UniConnect/
│   ├── UniConnect.xcodeproj/
│   └── UniConnect/
│       ├── Models/          # AppUser, Event, Post, FeedPost, Chat, Message, UserFollow…
│       ├── Services/        # AuthService, FirestoreService, StorageService
│       ├── ViewModels/
│       ├── Views/
│       │   ├── Auth/        # Login, Register, ForgotPassword
│       │   ├── Board/
│       │   ├── Chat/
│       │   ├── Events/
│       │   ├── Feed/
│       │   ├── Profile/
│       │   └── Components/
│       └── Utilities/
└── README.md
```

## Pokretanje u Xcode-u

1. Kloniraj repozitorijum i otvori **`UniConnect/UniConnect.xcodeproj`**.
2. U [Firebase konzoli](https://console.firebase.google.com) kreiraj iOS aplikaciju sa istim **Bundle ID** kao u Xcode-u.
3. Preuzmi **`GoogleService-Info.plist`** i dodaj ga u target **UniConnect** (*Copy items if needed*).
4. U Firebase uključi:
   - **Authentication → Email/Password**
   - **Cloud Firestore** (produkcijski režim + pravila)
   - **Storage** (bucket + pravila)
5. Objavi security rules i indekse (vidi ispod).
6. Pokreni na simulatoru ili uređaju (**⌘R**).

> **Napomena:** `GoogleService-Info.plist` sadrži konfiguraciju Firebase projekta. Za javni repozitorijum razmotri `.gitignore` za taj fajl.

## Firebase — kolekcije i Storage

| Resurs | Put / kolekcija |
|--------|------------------|
| Korisnici | `users/{uid}` |
| Praćenje | `users/{uid}/following/{targetId}` (keš: ime, slika) |
| Pratioci | `users/{uid}/followers/{followerId}` (keš: ime, slika) |
| Događaji | `events/{eventId}` |
| Oglasi | `posts/{postId}` |
| Feed | `feed_posts/{postId}` (koren + odgovori u istoj kolekciji) |
| Poruke | `chats/{chatId}` + podkolekcija `messages/{messageId}` |
| Profilne slike | `profile_images/{uid}.jpg` |
| Slike oglasa | `posts/{postId}/…` |
| Slike feeda | `feed_posts/{postId}/…` |
| Slike u chatu | `chats/{chatId}/…` |

Aplikacija koristi **Cloud Firestore**, ne Firebase Realtime Database.

Pri izmeni profila (ime/slika) aplikacija:
1. Ažurira `users/{uid}`
2. Sync-uje mirror u svim `following` / `followers` zapisima (collection group upit)
3. Liste i poruke prikazuju sveže podatke iz `users/{uid}` preko `AuthorProfileCache`

### Security rules

U korenu repoa su `firestore.rules` i `storage.rules`. U konzoli:

1. **Firestore Database → Rules** — kopiraj sadržaj `firestore.rules` → **Publish**
2. **Storage → Rules** — kopiraj sadržaj `storage.rules` → **Publish**

Opciono iz terminala (Firebase CLI):

```bash
firebase login
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### Indeksi

Za **sync profila u follow listama** potrebni su **single-field** exemption-i (Collection group scope):

| Collection group | Polje |
|------------------|--------|
| `following` | `targetUserId` |
| `followers` | `followerUserId` |

U konzoli: **Firestore → Indexes → Single field → Add exemption**, ili deploy `firestore.indexes.json` preko Firebase CLI.

Za pretragu korisnika po `displayName` konzola može zatražiti dodatni indeks — link iz greške u Xcode konzoli vodi na automatsku kreaciju.

## Licenca

Pogledaj fajl `LICENSE` u korenu repozitorijuma.

---

*UniConnect — studentska društvena platforma za univerzitetski kampus.*
