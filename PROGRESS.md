# PROGRESS: HEADCOUNT

Stan na 2026-11-10. Plik służy do wznowienia pracy w nowej sesji. Szczegółowe wyniki testów są w `docs/05_STATUS.md`, a lista assetów w `docs/06_ASSETS.md`.

## Aktualny stan projektu

Kooperacyjny horror psychologiczny na Roblox w fazie Vertical Slice (Misja 001). Lobby (Hub) i misja działają solo w Studio, z tymczasową oprawą z generatorów Roblox. Cała misja i droga przez lobby do terminala przeszły pieszo, bez teleportów (`docs/05_STATUS.md`, szósty przebieg).

- **Budowanie i testy:** `python scripts/check.py [--fix]` uruchamia rojo, lune, selene i stylua oraz tworzy `build/Hub.rbxl` i `build/Mission.rbxl`. Ostatni wynik: wszystko zielone, 65 testów.
- **Nazwa:** HEADCOUNT. „Poza kadrem” zostaje nazwą stanu w grze i ukrytego zakończenia. Dostępności nazwy na Roblox nie sprawdzono.
- **Git:** gałąź `main`, zdalne repozytorium pokazuje `git remote -v`. `build/` i `Place1.rbxl` są poza repozytorium. Plan rozwoju jest w `docs/07_ROADMAP.md`.
- **Publikacja na Roblox:** nic nie zostało opublikowane. `Config/Places` ma identyfikatory 0, więc teleport między miejscami nie może jeszcze działać. Publikacja wymaga wyraźnej zgody właściciela.
- **Grywalność:** gry nie przeszedł jeszcze żaden człowiek.

## Wykonane 2026-11-10

- Przegląd doświadczenia gracza bez nowej treści: audyt Misji 001 z perspektywy nowego gracza, uczciwszy Kadrowy (4 nowe testy, razem 65), spokojniejszy start, dokładne miejsce z taśmy, Bileter od drugiej wizyty, jeden system UI dla obu miejsc, nowa kamera (przesłona, pasek nagrania, znak zapisu), znacznik celu, oznaczenie obiektów, własne przyciski dotykowe, lista drużyny, jaśniejsze tło światła.
- Sprawdzone w Studio solo z prawdziwymi klawiszami i zrzutami: start, wizjer, nagranie, odtwarzanie, miejsce z taśmy, krzesło, karta wycięcia, raport porażki, ekran ładowania, terminal, układ przycisków dotykowych w małym oknie. Szczegóły i lista niesprawdzonych rzeczy: `docs/05_STATUS.md`, osiemnasty przebieg.
- Specyfikacje Kadrowego, widowni i brakujących dźwięków do zewnętrznej produkcji: `docs/06_ASSETS.md`.
- Nic nie jest zacommitowane ani opublikowane.

## Wykonane 2026-11-09

- Szkic Misji 002 „Kurs 17” w `docs/08_MISJA_002.md`: nocny autobus, Dubler powtarzający ruchy gracza sprzed 30 s, Kanar (bileter T. Malec), przystanki jako większe przestrzenie. Logika z testami: `Core/StandIn` i `Core/Route17` (8 testów, razem 61; decyzje projektowe na końcu dokumentu). Miejsca w Roblox jeszcze nie ma.
- Przeciwnicy i fabuła: Kadrowy porusza się poklatkowo, pochyla i sięga długą ręką; nowy przeciwnik Bileter w ciemności widzi tylko światło latarki; trzy nowe dokumenty i zapowiedź następnej taśmy. Audyt geometrii `lune run audit_map` znalazł i pomógł naprawić lampę w ścianie, donicę w regale i migającą boazerię. Szczegóły: `docs/05_STATUS.md`, siedemnasty przebieg.
- Wygląd: plakaty z lat 80. w sali, foyer i lobby (bez obrazków, z kształtów i czcionek), wygląd VHS w wizjerze i na taśmach, głębia ostrości, kurz w sali i w świetle projektora. Podgląd plakatów: `lune run poster_preview`. Szczegóły: `docs/05_STATUS.md`, szesnasty przebieg.
- Warunki nocy od drugiej wizyty: krótka taśma, niespokojny Kadrowy, słabe żarówki albo uważna sala (`Core/Conditions`). Szczegóły: `docs/05_STATUS.md`, piętnasty przebieg.
- Trendy 2026: rejestrowanie anomalii kamerą (styl Exit 8) i Kadrowy, który w ciszy słyszy głos z czatu głosowego. Szczegóły i źródła: `docs/05_STATUS.md`, czternasty przebieg.
- Więcej strachu: widownia obraca się do kamery od zaniku prądu, bicie serca i czerwona poświata przy Kadrowym, migające światła przy jego skokach, trzy nowe anomalie (szept imienia, twarz przed obiektywem, zaciemnienie).
- Większa piwnica: magazyn z regałami w kształcie węża, bezpiecznik na końcu pod czerwoną lampą.
- Kinowe plansze rozdziałów, znacznik RADIO w napisach, zasady w notatniku, obsługa kontrolera w panelach.
- Szczegóły: `docs/05_STATUS.md`, trzynasty przebieg. Nic z tego nie było uruchomione w Studio.
- Usunięta blokada misji: pudełko czystych kaset na ladzie kasy w foyer oddaje taśmę graczowi, który zużył wszystkie trzy.
- Notatnik terenowy (J / L1 / NOTES) w misji i panel pomocy w lobby: wskazówki, dokumenty do ponownego czytania, sterowanie, jasność.
- Karta celu pokazuje konkretny następny krok (`Core/Guide`, 3 nowe testy), a radio raz podpowiada, gdy gracz długo stoi w miejscu.
- PLAY SOLO w terminalu. Po taśmie napis, w którym rzędzie ktoś się odwrócił.
- Nic z tego nie było uruchomione w Studio. Szczegóły: `docs/05_STATUS.md`, dwunasty przebieg.

## Wykonane 2026-11-08

- Lobby: własny, cieplejszy preset światła, siatka paneli w hali, kinkiety, lampy nad recepcją, podświetlone tablice kierunkowe przy wejściu, światełka prowadzące do terminala, zegar 18:04, boazeria i kinkiety w korytarzu, kącik z krzesłami przed TV, rośliny. Nic z tego nie było obejrzane w Studio (`docs/05_STATUS.md`, jedenasty przebieg).

- Powrót po rozłączeniu do już zamkniętej ekspedycji odsyła gracza do huba zamiast tworzyć pusty przebieg.
- Okienko kasy w foyer nie jest już czarnym prostokątem, kotary przy ekranie są jaśniejsze.
- Nic z tego nie było uruchomione w Studio. Szczegóły: `docs/05_STATUS.md`, dziesiąty przebieg.

## Wykonane dzisiaj (pakiet przed testem)

- Angielski jest językiem podstawowym, także na szyldach. Polskie tłumaczenie jest wyłączone flagą `POLISH_TRANSLATION` w `Strings.luau`.
- Usunięte migotanie przy drzwiach (z-fighting) w lobby i misji. Zasada na przyszłość: elementy mają się stykać krawędziami albo wyraźnie przykrywać, nigdy nie leżeć w tej samej płaszczyźnie.
- Nowe dźwięki, klik błędu, muzyka w kulminacji i na końcu, tłumienie za ścianą. Nikt ich jeszcze nie słyszał.
- Autobus na końcu w `ViewportFrame`, ochrona taśmy przed przypadkowym R-R, poprawki sobowtóra.
- Szczegóły i testy: `docs/05_STATUS.md`, siódmy przebieg.

## Wykonane dzisiaj (przejście pieszo)

- Przejście całej misji Humanoidem: raz z wstrzymanym Kadrowym, raz z aktywnym. Bez blokad na trasach.
- Naprawione: dokumentów w misji nie dało się zamknąć myszą (przycisk X bez `Modal`), a na kontrolerze zamyka je teraz B.
- Naprawione: wskazówka z magnetofonu nachodziła na napis radia. Jest u góry obrazu, na własnym tle.
- Napis o powrocie przy znaczniku dostał obrys.
- Pliki: `src/mission/client/Controllers/Hud.luau`, `Playback.luau`, `OffFrameView.luau`, `docs/05_STATUS.md`, ten plik.

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
- Raz po jednym nagraniu serwer zaliczył dwie taśmy. Nie udało się tego odtworzyć w dwóch kolejnych przebiegach (`docs/05_STATUS.md`).

## Co zostało przetestowane

**Solo w Studio, na końcowej grafice, pieszo, z prawdziwymi klawiszami:** pełny łańcuch misji od Protocol do Done, także z aktywnym Kadrowym, wycięcie i powrót na znacznik, porażka po wycięciu, intro w lobby i dojście do terminala. Skrypt testowy ustawiał kierunek kamery i znał rozwiązanie. Szczegóły: `docs/05_STATUS.md`, szósty przebieg.

Pomiar sprzed tego etapu, ze Studio na tym komputerze: misja 1637 części, 482 siatki, 53–65 FPS; lobby 321 części, 184 siatki, 65 FPS.

**Tylko przed zmianą grafiki i skryptami:** wstawanie rzędów, Dubel 3.

**Nigdy nietestowane:**
- gra człowieka, czas przejścia, 2–4 graczy, telefon i fizyczny kontroler,
- teleport między miejscami i zapis w DataStore,
- brzmienie dźwięków,
- wygląd sobowtóra w ruchu w misji, pełny łańcuch misji po ostatnich zmianach geometrii.

## Dokładny następny krok

Właściciel gra sam, od początku do końca (krok 2 w `docs/07_ROADMAP.md`). Tego nie zastąpi żaden skrypt, bo główne pytania to: czy gra straszy, czy jest zrozumiała i ile trwa.

1. Uruchomić `python scripts/check.py` i otworzyć `build/Mission.rbxl`. Przywrócić zminimalizowane okno Studio, bo inaczej widok jest szary.
2. Zagrać bez korzystania z rozwiązania wypisanego w Output.
3. Zapisać: gdzie gra stanęła, co było niejasne, czy Kadrowy jest za trudny, czas przejścia i ocenę dźwięku.
4. Każdą blokadę naprawić u źródła i dopisać wynik do `docs/05_STATUS.md`.
5. Następnie test 2–3 osób bez instrukcji, a potem publikacja próbna według README, która wymaga zgody właściciela.

Atrybut `DevPauseRegistrar` na `Workspace`, ustawiony w trybie Edit przed Play, wstrzymuje Kadrowego na czas sprawdzania tras.
