# UniConnect

iOS aplikacija za **studentski kampus** — događaji, oglasi, feed objave, poruke, praćenje korisnika, profil i admin moderacija. Projekat je pisan u **SwiftUI** uz arhitekturu **MVVM** i backend **Firebase** (Auth, Cloud Firestore, Storage).

Diplomski rad — finalna verzija aplikacije.

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

## Tabovi aplikacije

| Tab | Sadržaj |
|-----|---------|
| **Događaji** | Lista, mapa, filter, RSVP, kreiranje i izmena |
| **Oglasi** | Lista, pretraga, filter, slike, kontakt prodavca |
| **Objave** | Feed sa threadovima, lajkovi, pretraga korisnika |
| **Poruke** | Real-time chat, slike, badge nepročitanih |
| **Profil** | Pregled, izmena, pratioci, tuđi profili |
| **Admin** | Samo za `role: admin` — moderacija i statistika |

## Funkcionalnosti

### Autentifikacija i nalog

- Prijava, registracija, odjava
- Zaboravljena lozinka (Firebase reset email)
- Verifikacija emaila — aplikacija je nedostupna dok korisnik ne potvrdi email
- Dokument korisnika u `users/{uid}` (ime, godina, smer, bio, profilna slika)
- Ban sistem — trajni ili vremenski ban; ekran `BannedView` blokira pristup

### Događaji

- Lista i mapa, filter po kategoriji, pretraga
- Kreiranje sa adresom → automatsko geokodiranje koordinata
- Detalj, RSVP, izmena i brisanje za organizatora
- Navigacija na profil organizatora
- Arhiviranje isteklih događaja (admin)

### Oglasi (Board)

- Lista, pretraga, filter po kategoriji
- Kreiranje sa više slika, detalj, izmena slika, brisanje
- Autor vidljiv u detalju; kontakt prodavca preko poruka (chat vezan za oglas)
- **Pošalji u chat** — deljenje oglasa drugom korisniku

### Feed (Objave)

- Korenske objave i threadovi (odgovori)
- Lajkovi, slike, brisanje sopstvenih objava i threadova
- Filter **Praćeni** / **Svi**
- Pretraga korisnika (lupa u toolbar-u)
- Navigacija na profil (avatar + ime)
- **Pošalji u chat** — deljenje objave preko context menija

### Praćenje i pretraga

- Zaprati / otprati korisnika
- Liste **Pratioci** i **Pratiš** na profilu
- Pretraga svih korisnika po imenu
- Novo ćaskanje samo sa korisnicima koje pratiš
- Sync mirror zapisa (`following` / `followers`) pri izmeni profila

### Profil

- Pregled i izmena (ime, godina, smer, bio, profilna slika)
- Tuđi profil sa sekcijama oglasa i feed objava autora
- Statistike (pratioci, pratiš, objave)

### Poruke

- Tab sa badge-om nepročitanih poruka
- Sekcije **Razgovori** i **Oglasi** (chat vezan za oglas)
- Real-time chat (Firestore listeneri)
- Tekst i slike u porukama
- Brisanje razgovora (pojedinačno ili višestruki izbor)
- DM sa profila; chat sa oglasa
- Svež avatar i ime sagovornika (`AuthorProfileCache`)
- **Deljeni sadržaj** — kartica u chatu (oglas / događaj / objava) sa navigacijom na original

### Prijave sadržaja

Korisnici mogu prijaviti:

- Oglas, događaj, feed objavu
- Korisnički profil
- Poruku u chatu (dugi pritisak)

Prijave se čuvaju u `reports` sa statusom `pending` / `resolved`.

### Admin panel

Dostupan samo korisnicima sa `role: admin` u Firestore-u.

- **Dashboard** — broj korisnika, oglasa, događaja, feed objava, prijava na čekanju (Firestore count agregacija)
- **Prijave** — folderi *Pending* i *Rešene*; pregled prijavljenog sadržaja
- **Moderacija** — ban / unban, brisanje sadržaja, brisanje profilne slike, arhiviranje događaja
- **Upravljanje korisnicima** — pretraga, pregled profila i statistika
- **Admin log** — zapis akcija u `admin_logs`


### Performanse

- Paralelno učitavanje tabova pri startu
- Firestore disk keš, `URLCache`
- `AuthorProfileCache` za autore i učesnike chata
- Optimistički lajkovi na feedu

## Arhitektura

```
UniConnectApp
  └── ContentView (auth / verifikacija / ban gate)
        └── MainTabView
              ├── ViewModels (Events, Board, Feed, Chat, Follow, Admin)
              ├── Services (Auth, Firestore, Storage, Admin)
              └── Views po modulima
```

| Sloj | Sadržaj |
|------|---------|
| **Models** | `AppUser`, `Event`, `Post`, `FeedPost`, `Chat`, `Message`, `UserFollow`, `UserFollower`, `Report`, `AdminLog`, `SharedContent` |
| **Services** | `AuthService`, `FirestoreService`, `StorageService`, `AdminService` |
| **ViewModels** | `AuthViewModel`, `EventsViewModel`, `BoardViewModel`, `FeedViewModel`, `ChatViewModel`, `FollowViewModel`, `AdminViewModel` |
| **Utilities** | keš, geokodiranje, kompresija slika, validacija, follow mirror migracija |

## Struktura repozitorijuma

```
UniConnect/
├── firebase.json
├── .firebaserc
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── scripts/                    # Admin i migracije (Node.js)
│   ├── create-admin.mjs
│   ├── migrate-followers-mirror.mjs
│   └── README.md
├── UniConnect/
│   ├── Assets.xcassets/        # App ikona + AccentColor
│   ├── UniConnect.xcodeproj/
│   └── UniConnect/
│       ├── Models/
│       ├── Services/
│       ├── ViewModels/
│       ├── Views/
│       │   ├── Admin/
│       │   ├── Auth/
│       │   ├── Board/
│       │   ├── Chat/
│       │   ├── Components/
│       │   ├── Events/
│       │   ├── Feed/
│       │   └── Profile/
│       └── Utilities/
└── README.md
```


## Firebase — kolekcije i Storage

| Resurs | Put / kolekcija |
|--------|------------------|
| Korisnici | `users/{uid}` |
| Praćenje | `users/{uid}/following/{targetId}` |
| Pratioci | `users/{uid}/followers/{followerId}` |
| Događaji | `events/{eventId}` |
| Oglasi | `posts/{postId}` |
| Feed | `feed_posts/{postId}` |
| Poruke | `chats/{chatId}` + `messages/{messageId}` |
| Prijave | `reports/{reportId}` |
| Admin log | `admin_logs/{logId}` |
| Profilne slike | `profile_images/{uid}.jpg` |
| Slike oglasa | `posts/{postId}/…` |
| Slike feeda | `feed_posts/{postId}/…` |
| Slike u chatu | `chats/{chatId}/…` |

Aplikacija koristi **Cloud Firestore**, ne Firebase Realtime Database.

Pri izmeni profila (ime/slika) aplikacija:

1. Ažurira `users/{uid}`
2. Sync-uje mirror u svim `following` / `followers` zapisima (collection group upit)
3. Liste i poruke prikazuju sveže podatke preko `AuthorProfileCache`

### Security rules

U korenu repoa su `firestore.rules` i `storage.rules`. U konzoli:

1. **Firestore Database → Rules** — kopiraj sadržaj `firestore.rules` → **Publish**
2. **Storage → Rules** — kopiraj sadržaj `storage.rules` → **Publish**

Iz terminala (Firebase CLI):

```bash
firebase login
firebase use --add    # ili koristi postojeći .firebaserc
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Pravila pokrivaju: verifikovan email, ban, admin ulogu, vlasništvo nad sadržajem, prijave i chat učesnike.

### Indeksi

Za **sync profila u follow listama** potrebni su **single-field** exemption-i (Collection group scope):

| Collection group | Polje |
|------------------|--------|
| `following` | `targetUserId` |
| `followers` | `followerUserId` |

U konzoli: **Firestore → Indexes → Single field → Add exemption**, ili deploy `firestore.indexes.json` preko Firebase CLI.

Za pretragu korisnika po `displayName` konzola može zatražiti dodatni indeks — link iz greške u Xcode konzoli vodi na automatsku kreaciju.

## Admin nalog 


Podrazumevano: `admin@gmail.com` / `admin123` — samo za razvoj i demonstraciju na odbrani.


## Licenca

Pogledaj fajl `LICENSE` u korenu repozitorijuma.

---

*UniConnect — studentska društvena platforma za univerzitetski kampus.*
