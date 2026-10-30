# Tavli

[Srpski](#srpski) | [English](#english)

## Srpski

**Od ideje za obrok do recepta po tvom ukusu.**

Tavli je lična zbirka recepata i pomoćnik u kuhinji. Uslikaj jelo, unesi njegov
naziv ili zapiši svoj recept — a zatim ga prilagodi kroz razgovor sa AI
pomoćnikom. Zameni sastojke, promeni broj porcija ili pojednostavi pripremu,
uz istoriju izmena koja ti omogućava da se vratiš na prethodnu verziju.

Recepti se čuvaju na tvom uređaju i dostupni su za pregled i uređivanje bez
interneta. Interfejs je na srpskom jeziku, latinicom, i prilagođen telefonu,
tabletu i računaru. Internet je potreban za AI funkcije.

### Šta Tavli trenutno omogućava

- Kreiranje recepata iz fotografije, naziva jela ili ručnim unosom.
- Pregled predloga pre čuvanja i pretragu sačuvanih recepata.
- Prilagođavanje recepata kroz AI razgovor, uz vraćanje prethodnih verzija.
- Korišćenje Gemini, Groq i OpenRouter servisa, sa automatskim prelaskom na
  sledeći model kada prethodni nije dostupan.
- Dodavanje sopstvenih API ključeva i njihovo čuvanje u bezbednom skladištu
  uređaja.

### U planu

Planiranje obroka, evidencija namirnica u ostavi i liste za kupovinu povezaće
recepte sa svakodnevnom organizacijom kuhinje. Predlozi jela uzimaće u obzir
dostupne namirnice, ukus i potrebe domaćinstva.

Detaljan pregled razvoja nalazi se u [planu razvoja](docs/roadmap.md).

### Tehnologije

Razvijeno u Flutteru za Android, iOS i macOS. Podaci se čuvaju lokalno uz
Drift (SQLite), stanje aplikacije vodi Riverpod, a navigaciju go_router.

## English

**From a meal idea to a recipe that suits your taste.**

Tavli is your personal recipe collection and kitchen companion. Take a photo
of a dish, enter its name, or write your own recipe — then make it your own
through a conversation with an AI assistant. Swap ingredients, adjust the
number of servings, or simplify the preparation, with version history that
lets you return to an earlier version.

Recipes are stored on your device and available to browse and edit offline.
The interface is in Serbian (Latin script), with layouts for phones, tablets,
and desktops. AI features require an internet connection.

### Current features

- Create recipes from a photo, a dish name, or manual entry.
- Preview suggestions before saving and search your saved recipes.
- Adapt recipes through AI chat and restore previous versions.
- Use Gemini, Groq, and OpenRouter, with automatic fallback to the next model
  when the previous one is unavailable.
- Add your own API keys and keep them in your device's secure storage.

### Planned features

Meal planning, pantry tracking, and shopping lists will connect your recipes
with everyday kitchen routines. Dish suggestions will take into account the
ingredients you have, your tastes, and your household's needs.

See the [roadmap](docs/roadmap.md) for a detailed development overview.

### Technology

Built with Flutter for Android, iOS, and macOS. Drift (SQLite) stores data
locally, Riverpod manages application state, and go_router handles navigation.
