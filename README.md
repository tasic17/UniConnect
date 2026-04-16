# UniConnect

iOS aplikacija za **studentski kampus** — objedinjuje događaje, (u planu) oglasnu tablu, feed i poruke. Projekat je pisan u **SwiftUI** uz arhitekturu **MVVM** i backend **Firebase** (autentifikacija i Firestore).

## Tehnologije

| Oblast | Izbor |
|--------|--------|
| Jezik | Swift 5.9+ |
| UI | SwiftUI |
| Arhitektura | MVVM (`ViewModel` + `Service` sloj) |
| Backend | Firebase Auth, Cloud Firestore |
| Mape | MapKit, geokodiranje adresa |

Minimalna verzija iOS-a odredi u Xcode projektu (preporuka: **iOS 17+** ako koristiš novije MapKit API-je).

## Funkcionalnosti (stanje razvoja)

- **Autentifikacija** — prijava, registracija, odjava; korisnički dokument u Firestore (`users`).
- **Događaji** — lista i mapa, filteri po kategoriji, kreiranje događaja (adresa → koordinate), detalj, RSVP, brisanje/izmena za organizatora.
- **Profil** — pregled i izmena podataka.
- **U izradi / placeholder** — tabovi *Oglasi*, *Feed* i *Poruke* u `MainTabView` (modeli i Firestore servisi mogu biti pripremljeni za naredne faze).

## Struktura repozitorijuma

```
UniConnect/
├── UniConnect.xcodeproj/   # Xcode projekat + Swift Package Manager (Firebase)
├── UniConnect/               # Izvorni kod aplikacije
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   └── Utilities/
└── README.md
```

## Pokretanje u Xcode-u

1. Kloniraj repozitorijum i otvori **`UniConnect/UniConnect.xcodeproj`**.
2. U [Firebase konzoli](https://console.firebase.google.com) kreiraj iOS aplikaciju sa istim **Bundle ID** kao u Xcode-u.
3. Preuzmi **`GoogleService-Info.plist`** i dodaj ga u projekat (target **UniConnect**), sa uključenom opcijom *Copy items if needed*.
4. U Firebase uključi **Authentication → Email/Password** i kreiraj **Firestore** bazu; uskladi **security rules** sa šemom kolekcija (`events`, `users`, itd.).
5. Izaberi šemu (**UniConnect**) i pokreni na simulatoru ili uređaju (**⌘R**).

> **Napomena:** `GoogleService-Info.plist` sadrži konfiguraciju projekta na Firebase-u. Za javni repozitorijum razmotri `.gitignore` za taj fajl i uputstvo u README kako ga lokalno dodati.

## Firebase / Firestore (kratko)

- Korisnici: kolekcija `users`.
- Događaji: kolekcija `events` (polja u skladu sa modelom `Event`, uključujući `attendees`, `attendeesCount`, opciono `latitude` / `longitude`).

Za složene upite (npr. `posts` sa `where` + `orderBy`) Firebase konzola može zatražiti **kompozitni indeks** — link iz greške u Xcode konzoli vodi na automatsku kreaciju.

## Licenca

Pogledaj fajl `LICENSE` u korenu repozitorijuma.

---

*UniConnect — studentska društvena platforma za univerzitetski kampus.*
