# PROGRESS: HEADCOUNT

Stan na 2026-11-07. Plik służy do wznowienia pracy w nowej sesji. Szczegółowe wyniki testów są w `docs/05_STATUS.md`, a lista assetów w `docs/06_ASSETS.md`.

## Aktualny stan projektu

Kooperacyjny horror psychologiczny na Roblox w fazie Vertical Slice (Misja 001). Lobby (Hub) i misja działają solo w Studio, z tymczasową oprawą z generatorów Roblox.

- **Budowanie i testy:** `python scripts/check.py [--fix]` uruchamia rojo, lune, selene i stylua oraz tworzy `build/Hub.rbxl` i `build/Mission.rbxl`. Ostatni wynik: wszystko zielone, 46 testów.
- **Nazwa:** HEADCOUNT. „Poza kadrem” zostaje nazwą stanu w grze i ukrytego zakończenia. Dostępności nazwy na Roblox nie sprawdzono.
- **Git:** gałąź `main`, zdalne repozytorium pokazuje `git remote -v`. `build/` i `Place1.rbxl` są poza repozytorium. Plan rozwoju jest w `docs/07_ROADMAP.md`.
- **Publikacja na Roblox:** nic nie zostało opublikowane. `Config/Places` ma identyfikatory 0, więc teleport między miejscami nie może jeszcze działać. Publikacja wymaga wyraźnej zgody właściciela.
- **Grywalność:** gry nie przeszedł jeszcze żaden człowiek.

## Wykonane dzisiaj (etap grafiki i modeli)

- Naprawiono zamurowane drzwi z foyer do sali. Bez tego żaden gracz nie wszedłby do sali.
- Dodano materiały powierzchni i model każdego kluczowego rekwizytu oraz postaci.
- Skalibrowano krzesła, widownię, włosy i paski na oczach. Wszystkie trzy modele widowni mają teraz tę samą siatkę.
- Dodano wstępne ładowanie modeli i ciemny kolor zapasowy na czas ładowania.
- Dodano w misji bojler i lampę, a w lobby automat na kawę, kartony, terminal na biurku i ciemny blat lady.
- Przyciemniono dywan, ściany i fornir.

## Zmodyfikowane pliki (ten etap)

Brak gita oznacza brak pełnego diffu. Wcześniejsze etapy tego samego dnia zmieniały też inne pliki.

| Obszar | Pliki |
|---|---|
| Nowy kod | `src/shared/Core/WallSpans.luau` |
| Świat | `src/shared/World/Build.luau`, `Props.luau`, `Surfaces.luau` |
| Misja, serwer | `src/mission/server/Services/MissionDressing.luau`, `MissionAnnex.luau` |
| Misja, klient | `src/mission/client/Boot.client.luau`, `Controllers/Audience.luau`, `Controllers/RegistrarView.luau` |
| Lobby | `src/hub/server/Services/HubDressing.luau`, `src/hub/client/Boot.client.luau`, `Controllers/Intro.luau` |
| Assety | `src/shared/Models/*.rbxmx`, `src/materials/*.model.json` |
| Projekt Rojo | `hub.project.json`, `mission.project.json` |
| Testy | `tests/Core.spec.luau` |
| Dokumentacja | `docs/05_STATUS.md`, `docs/06_ASSETS.md` |

## Ważne decyzje techniczne

- **Ściany:** `WallSpans.solve` dzieli ścianę na kolumny, więc otwory mogą się nakładać. Korzystają z niego `Build.wallX` i `Build.wallZ`.
- **Modele:** skrypt nie może ustawić `MeshId`, więc każdy model to plik `.rbxmx` stawiany przez `Props.place`.
- **`InitialSize`:** musi być prawdziwym rozmiarem siatki, zmierzonym przez `AssetService:CreateMeshPartAsync`. Przeteksturowanie może zwrócić siatkę o innych wymiarach, a błędna wartość cicho psuje skalę i położenie.
- **Kolor modeli:** tekstura `MeshPart` ignoruje `Color`, więc zbyt jasny model trzeba przeteksturować.
- **Materiały:** `Surfaces.apply` przydziela je według koloru z palety, więc wymiana nie wymaga zmian w kodzie poziomów. Beton w piwnicy zostaje bez zmian.
- **Kalibracja widowni:** `Props.sitter` ma `SCALE` 2.4 i `LIFT` 0.2, krzesło ma skalę 1.5 i siedzisko na wysokości 1.65.
- **Ukryte drzwi:** część `StageBack` w otworach drzwi archiwum to celowa zaślepka z mechaniki kadru, a nie błąd.
- **Lada w lobby:** została brylą z fornirem. Wygenerowany model wyglądał gorzej i został usunięty.
- **Generator assetów:** `assets.py` leży w scratchpadzie poprzedniej sesji, poza projektem, i może zniknąć. Źródłem prawdy są pliki w `src/shared/Models` i `src/materials`. Nowy model można dodać ręcznie według `docs/06_ASSETS.md`.

## Aktualne błędy i problemy

- Świeże assety zgłaszają w konsoli „Asset content representation is being generated” i mogą przez chwilę nie być widoczne.
- Nieznane jest źródło komunikatu o `rbxassetid://203785492` (zły typ assetu).
- Podczas `screen_capture` wizjer kilka razy zmienił stan bez naciśnięcia Q. Przyczyna nie została ustalona; może to być efekt narzędzia, ale błędu w grze nie wykluczono.
- PathfindingService zwraca `NoPath` dla piwnicy, biura i archiwum. Piwnica i wejście do biura przeszły pieszo, a archiwum jest zamknięte do fazy Door. Lobby zwraca `NoPath` dla wszystkich testowanych celów, ale przyczyny nie ustalono.
- Wizualnie: kartony w lobby są różowawe, regały mają trójkątne artefakty tekstury, lada i czerwone lampy awaryjne to bryły.
- Wszystkie modele są tymczasowe. Główne, zwłaszcza Kadrowy i widownię, trzeba przed premierą zastąpić ręcznie robionymi.

## Co zostało przetestowane

**Solo w Studio, na tym etapie:**
- Humanoid doszedł ze startu do sali przez drzwi foyer (końcowa wersja, 7 s).
- Humanoid przeszedł z sali przez korytarz i rampę do piwnicy (przed dodaniem modeli bojlera i lampy).
- Humanoid przeszedł przez wejście z sali do biura (start skryptem tuż przed drzwiami).
- Obejrzano na zrzutach salę, foyer, szatnię, kabinę, archiwum, biuro, piwnicę, Kadrowego i hol lobby.
- Misja: 1637 części, 482 siatki, 53–65 FPS. Lobby: 321 części, 184 siatki, 65 FPS. Pomiar ze Studio na tym komputerze.

**Tylko przed zmianą grafiki, skryptami i z teleportami:** pełny łańcuch misji, przepływ lobby, szafka, klawiatura kodu, wstawanie rzędów, Dubel 3.

**Nigdy nietestowane:**
- gra człowieka, 2–4 graczy, telefon i kontroler,
- teleport między miejscami i zapis w DataStore,
- brzmienie dźwięków,
- Dubel 2 w grze oraz sobowtór oglądany w ruchu w misji.

## Dokładny następny krok

Przejść całą Misję 001 Humanoidem, bez teleportowania postaci, na świeżym buildzie:

1. Uruchomić `python scripts/check.py` i otworzyć `build/Mission.rbxl`. Przywrócić zminimalizowane okno Studio, bo inaczej widok jest szary.
2. Przejść kolejno fazy Protocol, Power, Projector, Door, Register, Climax i Done, korzystając z prawdziwych promptów i klawiszy.
3. Sprawdzić szczególnie przejście przez ukryte drzwi do archiwum oraz drogę powrotną. Bojler ma nową, mniejszą bryłę kolizji, więc trzeba też sprawdzić poruszanie się po piwnicy.
4. Po każdej znalezionej blokadzie naprawić przyczynę i dopisać wynik do `docs/05_STATUS.md`.
5. Potem przejść pieszo intro w lobby aż do terminala, a następnie przekazać grę właścicielowi do testu na żywo.

Atrybut `DevPauseRegistrar` na `Workspace`, ustawiony w trybie Edit przed Play, wstrzymuje Kadrowego na czas sprawdzania tras. Do końcowego przejścia trzeba go wyłączyć.
