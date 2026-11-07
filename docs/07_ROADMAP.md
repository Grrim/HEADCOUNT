# 07. Plan rozwoju

Stan na 2026-11-07. Kolejność wynika z ryzyka: najpierw sprawdzamy, czy gra działa i czy straszy, a dopiero potem rozbudowujemy treść. Terminów celowo nie podaję, bo nie mamy jeszcze danych z testów. Szczegóły projektowe są w `02_GDD.md`, a aktualne wyniki testów w `05_STATUS.md`.

## Gdzie jesteśmy

**Zrobione:**
- lobby Archiwum 03 z intrem, drużynami 1–4 osób i archiwum dokumentów,
- pełna Misja 001 „Zebranie” z kamerą, taśmami, Kadrowym, zagadkami i zakończeniem,
- mechaniki wycięcia, ratunku i omenów,
- tymczasowa oprawa z generatorów,
- teksty po angielsku (polskie tłumaczenie czeka wyłączone) oraz sterowanie na PC, kontroler i ekran dotykowy.

**Niesprawdzone:** gra człowieka, 2–4 graczy, telefon, kontroler, teleport i zapis postępów. Do tego czasu slice nie jest uznany za działający.

## Etap 1: Domknięcie Vertical Slice

Tu jesteśmy. Etap kończy się, gdy gra spełni wszystkie kryteria z `04_BACKLOG.md`.

1. ~~Przejść całą misję Humanoidem, bez teleportów, i naprawić znalezione blokady.~~ Zrobione 2026-11-07, wyniki w `05_STATUS.md`.
2. Właściciel przechodzi grę sam od początku do końca. To teraz następny krok.
3. 2–3 osoby grają bez instrukcji. Główne pytanie: czy same odkrywają, że odtworzenie nagrania przybliża Kadrowego?
4. Publikacja próbna według README. Decyzja o nazwie zapada po sprawdzeniu dostępności „HEADCOUNT”.
5. Testy na opublikowanej grze: teleport, zapis, rozłączenia, 2 i 4 graczy.
6. Test na prawdziwym telefonie: minimum 30 FPS, przyciski, czytelność.
7. Strojenie według wyników: długość misji (cel 15–25 minut), trudność Kadrowego, jasność, dźwięk.

**Decyzja na koniec etapu:** jeśli testerzy się nie boją albo nie rozumieją mechaniki, poprawiamy rdzeń, zanim powstanie kolejna misja.

## Etap 2: Jakość przed premierą

- Ręcznie robione modele Kadrowego i widowni, potem pozostałych rekwizytów fabularnych (`06_ASSETS.md`).
- Własny zestaw dźwięków zamiast tymczasowych z Creator Store.
- Ikona, miniatury i opis gry.
- Kwestionariusz Maturity & Compliance, z celem Mild.
- Podstawowa analityka: gdzie gracze odpadają, czas misji, wyniki drużyn.
- Testy zamknięte w większej grupie i poprawki.

## Etap 3: Premiera Misji 001

- Publiczna premiera jednej dopracowanej misji.
- Serwery prywatne jako pierwsza, prosta płatność.
- Zbieranie danych: retencja, długość sesji, liczebność drużyn.
- Poprawki po premierze, zanim ruszy Misja 002.

## Etap 4: Sezon 1

Każda misja wnosi jeden nowy pomysł. Kolejne ruszają dopiero, gdy poprzednia się sprawdzi.

| # | Tytuł | Miejsce | Nowy pomysł |
|---|---|---|---|
| 002 | Kurs 17 | Nocny autobus | Dubler powtarza ruchy gracza |
| 003 | Pion | Klatka bloku | Numery pięter zależą od taśmy |
| 004 | Turnus | Sanatorium | Dr Wrona, dorysowywanie klatek |
| 005 | Taśma Zero | Archiwum 03 | Lobby staje się misją; cztery zakończenia |

## Etap 5: Monetyzacja i rozwój po sezonie

**Tak, po Vertical Slice i bez przewagi w grze:** warianty kamery, personalizacja szafki, stroje i identyfikatory Biura, pakiet drużynowy.

**Nigdy:** dodatkowe taśmy, baterie, „ożywienia” za pieniądze i płatne losowe przedmioty.

Oceny opłacalności w GDD to szacunki sprzed danych, więc zweryfikujemy je analityką.

## Odłożone do czasu testu slice

Kosmetyka, kolejne misje, osiągnięcia w interfejsie, statyw i globalna lista drużyn.
