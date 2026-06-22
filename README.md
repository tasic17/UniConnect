# UniConnect

iOS aplikacija za **studentski kampus** — događaji, oglasi, feed objave, profil i (u planu) poruke. Projekat je pisan u **SwiftUI** uz arhitekturu **MVVM** i backend **Firebase** (Auth, Cloud Firestore, Storage).

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

- **Autentifikacija** — prijava, registracija, odjava; dokument korisnika u `users/{uid}`; verifikacioni email pri registraciji.
- **Događaji** — lista i mapa, filter po kategoriji, kreiranje (adresa → koordinate), detalj, RSVP, izmena/brisanje za organizatora; navigacija na profil organizatora.
- **Oglasi (board)** — lista, pretraga, filter kategorije, kreiranje sa slikama, detalj, izmena slika (zadrži/dodaj/obriši), brisanje; profil autora.
- **Feed** — korenske objave, threadovi (odgovori), lajkovi, slike, filter „Moj smer”, brisanje thread-a; odgovor sa preview slika; navigacija na profil (avatar + ime).
- **Profil** — pregled i izmena (ime, godina, smer, bio, profilna slika); tuđi profil (`UserProfileView`); sekcije oglasa i feed objava autora (uredi/obriši sopstvene).
- **Performanse** — paralelno učitavanje tabova, Firestore disk keš, `URLCache`, prefetch avatara u feedu.

### U planu

- **Poruke** — tab je placeholder u `MainTabView`; modeli `Chat` / `Message` i Firestore pravila za `chats` su pripremljeni.

## Struktura repozitorijuma

```
UniConnect/
├── firebase.json           # Firebase CLI (opciono)
├── firestore.rules         # Firestore security rules
├── storage.rules           # Storage security rules
├── UniConnect/
│   ├── UniConnect.xcodeproj/
│   └── UniConnect/
│       ├── Models/         # AppUser, Event, Post, FeedPost, Chat, Message
│       ├── Services/       # AuthService, FirestoreService, StorageService
│       ├── ViewModels/
│       ├── Views/
│       │   ├── Auth/
│       │   ├── Board/
│       │   ├── Events/
│       │   ├── Feed/
│       │   └── Profile/
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
5. Objavi security rules (vidi ispod).
6. Pokreni na simulatoru ili uređaju (**⌘R**).

> **Napomena:** `GoogleService-Info.plist` sadrži konfiguraciju Firebase projekta. Za javni repozitorijum razmotri `.gitignore` za taj fajl.

## Firebase — kolekcije i Storage

| Resurs | Put / kolekcija |
|--------|------------------|
| Korisnici | `users/{uid}` |
| Događaji | `events/{eventId}` |
| Oglasi | `posts/{postId}` |
| Feed | `feed_posts/{postId}` (koren + odgovori u istoj kolekciji) |
| Poruke (plan) | `chats/{chatId}` + `messages/{messageId}` |
| Profilne slike | `profile_images/{uid}.jpg` |
| Slike oglasa | `posts/{postId}/…` |
| Slike feeda | `feed_posts/{postId}/…` |

Aplikacija koristi **Cloud Firestore**, ne Firebase Realtime Database.

### Security rules

U korenu repoa su `firestore.rules` i `storage.rules`. U konzoli:

1. **Firestore Database → Rules** — kopiraj sadržaj `firestore.rules` → **Publish**
2. **Storage → Rules** — kopiraj sadržaj `storage.rules` → **Publish**

Opciono iz terminala (Firebase CLI):

```bash
firebase login
firebase use --add
firebase deploy --only firestore:rules,storage
```

### Indeksi

Za neke upite (npr. `where` + `orderBy`) konzola može zatražiti **kompozitni indeks** — link iz greške u Xcode konzoli vodi na automatsku kreaciju. Deo filtera/sortiranja je namerno na klijentu da se izbegnu nepotrebni indeksi.

## Licenca

Pogledaj fajl `LICENSE` u korenu repozitorijuma.

---

*UniConnect — studentska društvena platforma za univerzitetski kampus.*
