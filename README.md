# HEADCOUNT

Kooperacyjny horror na Roblox (1–4 graczy). Kamera pokazuje to, czego nie widzi oko, a każde odtworzenie nagrania przybliża to, co jest na taśmie.

- Koncepcja i projekt: [docs/02_GDD.md](docs/02_GDD.md)
- Architektura: [docs/03_TDD.md](docs/03_TDD.md)
- Aktualny stan, testy i znane problemy: [docs/05_STATUS.md](docs/05_STATUS.md)
- Plan rozwoju: [docs/07_ROADMAP.md](docs/07_ROADMAP.md)
- Punkt wznowienia pracy: [PROGRESS.md](PROGRESS.md)

Język gry to angielski, także na szyldach w świecie. Polskie tłumaczenie czeka w `src/shared/Strings.luau`, wyłączone flagą `POLISH_TRANSLATION`.

## Co jest zrobione

Stan na 2026-11-07. Faza Vertical Slice: jedna misja i lobby, z tymczasową grafiką i tymczasowymi dźwiękami.

- **Lobby Archiwum 03:** intro z kamerą, drużyny 1–4 osób, terminal ekspedycji, archiwum dokumentów, szafka z ramkami wizjera, ukryty pokój.
- **Misja 001 „The Meeting”:** cały łańcuch od weryfikacji obecności przez krzesła, szatnię, zanik prądu, kod na bezpieczniku, magnetofon, projektor, ukryte drzwi i rejestr po dzwonek i finałową taśmę.
- **Mechaniki:** wizjer pokazujący niewidzialną widownię, nagrywanie i odtwarzanie taśm, Kadrowy przybliżany każdym odtworzeniem, wycięcie z kadru z powrotem, anomalie i sobowtór.
- **Dane i sterowanie (napisane, nieprzetestowane):** teleport między miejscami, zapis w DataStore, przyciski dotykowe i kontroler.

Ostatnio:

- Notatnik terenowy (J): zapisuje wskazówki, pozwala ponownie przeczytać dokumenty, pokazuje sterowanie i ma suwak jasności. Karta celu ma linię „NEXT” z konkretnym następnym krokiem, a radio podpowiada, gdy gracz długo stoi w miejscu.
- Pudełko czystych kaset na ladzie kasy w foyer: gracz, któremu skończyła się taśma, nie utknie już na stałe.
- Terminal ma przycisk PLAY SOLO, który startuje misję jednym kliknięciem.
- Więcej strachu: widownia w wizjerze obraca się w stronę kamery, bliskość Kadrowego słychać i widać, nowe anomalie, kinowe plansze rozdziałów.
- Piwnica rozbudowana o ciemny magazyn z regałami. Bezpiecznik jest na końcu długiej alejki.
- Cała misja i droga do terminala przeszły pieszo w Studio, bez teleportów.
- Dokumenty w misji da się zamknąć, a wskazówka z magnetofonu nie nachodzi na napisy radia.
- Usunięte migotanie grafiki przy drzwiach (nakładające się powierzchnie) w lobby i misji.
- Uzupełniony tymczasowy zestaw dźwięków: szum budynku, sygnał błędu, muzyka w kulminacji i na końcu, tłumienie dźwięków za ścianą.
- Czytelna scena autobusu na końcu, ochrona taśm przed przypadkowym podwójnym R, poprawki sobowtóra.
- Ramy drzwi w lobby oraz zegar i napis EXIT, które zmieniają się w kulminacji.

**Czego jeszcze nikt nie sprawdził:** gry człowieka, czasu przejścia, brzmienia dźwięków, 2–4 graczy, telefonu, fizycznego kontrolera, teleportu i zapisu. Do tego czasu slice nie jest uznany za działający. Wyniki testów są w [docs/05_STATUS.md](docs/05_STATUS.md).

## Plany rozwoju

Kolejność wynika z ryzyka: najpierw sprawdzamy, czy gra działa i czy straszy, a dopiero potem rozbudowujemy treść. Szczegóły są w [docs/07_ROADMAP.md](docs/07_ROADMAP.md).

1. **Domknięcie slice (teraz):**
   - właściciel przechodzi grę sam, od początku do końca,
   - 2–3 osoby grają bez instrukcji,
   - publikacja próbna i testy na niej: teleport, zapis, rozłączenia, 2 i 4 graczy,
   - telefon: minimum 30 FPS, przyciski, czytelność,
   - strojenie długości misji (cel 15–25 minut), trudności Kadrowego, jasności i dźwięku.
2. **Jakość przed premierą:** ręcznie robione modele Kadrowego i widowni, własny zestaw dźwięków, ikona, miniatury i opis, kwestionariusz Maturity & Compliance (cel Mild), podstawowa analityka, testy zamknięte.
3. **Premiera Misji 001:** serwery prywatne jako pierwsza płatność, zbieranie danych o retencji, poprawki.
4. **Sezon 1:** misje 002 „Kurs 17”, 003 „Pion”, 004 „Turnus” i 005 „Taśma Zero”. Kolejna rusza dopiero, gdy poprzednia się sprawdzi.
5. **Po sezonie:** warianty kamery, personalizacja szafki, stroje i identyfikatory, pakiet drużynowy. Bez przewagi w grze: nigdy dodatkowe taśmy, baterie, „ożywienia” za pieniądze ani płatne losowe przedmioty.

Jeśli testerzy się nie boją albo nie rozumieją mechaniki, poprawiamy rdzeń gry, zanim powstanie kolejna misja.

## Praca z projektem

Narzędzia są przypięte w `rokit.toml`:

```bash
rokit install
```

Bramki jakości (budowa obu miejsc, testy logiki, lint, formatowanie):

```bash
python scripts/check.py
```

Wynik trafia do `build/Hub.rbxl` i `build/Mission.rbxl`. Otwórz je w Studio i uruchom Play. Źródłem prawdy jest dysk, więc **nie edytuj skryptów w Studio**.

## Sterowanie

| Akcja | PC | Kontroler |
|---|---|---|
| Interakcja | E | X |
| Kamera | PPM lub Q | L2 |
| Nagraj | R | R2 |
| Odtwórz ostatnią taśmę | T | Y |
| Latarka | F | D-pad góra |
| Komunikaty radiowe | 1–4 | D-pad lewo/prawo/dół, B |
| Pukanie (poza kadrem) | K | X |
| Notatnik: wskazówki, dokumenty, sterowanie, jasność | J | L1 |

Na urządzeniach dotykowych te same akcje są pod przyciskami ekranowymi, a notatnik otwiera przycisk NOTES w prawym górnym rogu. W lobby J otwiera pomoc z opisem pomieszczeń.

W Studio serwer misji wypisuje w Output rozwiązanie zagadki. Na żywym serwerze ten kod się nie wykonuje.

## Publikacja (kroki właściciela)

1. Opublikuj `build/Hub.rbxl` jako Start Place nowego doświadczenia.
2. Dodaj drugie miejsce w tym doświadczeniu i opublikuj do niego `build/Mission.rbxl`.
3. Wpisz oba ID do `src/shared/Config/Places.luau`, przebuduj i opublikuj oba miejsca ponownie.
4. W Creator Hub ustaw dla misji Access Control na **Secure within universe only**.
5. W Game Settings włącz dostęp do API (Enable Studio Access to API Services) do testów DataStore.
6. Wypełnij kwestionariusz Maturity & Compliance. Cel to Mild.
