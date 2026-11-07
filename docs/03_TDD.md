# 03. Technical Design Document

Wersja 0.1, 2026-11-06. API sprawdzone w dokumentacji Roblox tego dnia (patrz `00_RESEARCH.md`).

## 1. Główne decyzje

| Decyzja | Wybór | Uzasadnienie |
|---|---|---|
| Źródło prawdy | Dysk + Rojo, dwa pliki `*.project.json` | Kontrola wersji i testy bez Studio. Nie edytujemy skryptów w Studio |
| Framework | **Własny, 30-liniowy loader** zamiast Knit | Mniej zależności i prostszy kod. Lifecycle to `init()` / `start()` |
| Transport | Jeden `Net.luau`, zwykłe RemoteEvents | Wszystkie nazwy w jednym miejscu, walidacja na serwerze |
| RemoteFunction | **Brak** | Klient może zawiesić serwer przez brak odpowiedzi; zapytanie i odpowiedź realizują dwa eventy |
| Logika | Czyste moduły `Core/` bez Instance | Testy w Lune bez silnika |
| Mapa | Generowana kodem na starcie (szary box) | Powtarzalna, na dysku, szybka iteracja. Art pass później podmieni modele |
| Warstwa taśmy | Instance tylko po stronie klienta | Różne widoki dla różnych graczy bez obciążania replikacji |
| Nagrania | Dane (ścieżka kamery, pozycje), nie obraz | Jedyne wykonalne rozwiązanie. `ViewportFrame` odrzucony, bo oświetlenie nie zgadza się z głównym obrazem |
| Matchmaking | **Bez MemoryStore w drużynach** | Drużyny na jednym serwerze huba; znajomi dołączają przez zaproszenie. Globalna kolejka nie ma sensu przy niskim CCU na starcie |
| MemoryStore | Tylko powrót do misji | Krótki TTL, jeden klucz na gracza |
| Zapis | Scalanie monotoniczne w `UpdateAsync` | Rozwiązuje wyścig hub↔misja przy teleporcie bez blokady sesji |
| StreamingEnabled | **Wyłączony w slice** | Mała mapa wewnątrz budynku, poniżej ~3000 części. Prompty i węzły muszą istnieć na kliencie. Włączamy przy większych misjach po pomiarach |

## 2. Struktura Places

```
Experience: HEADCOUNT
├─ Place 1: HUB (start place)        hub.project.json
└─ Place 2: MISSION_001              mission.project.json
   Kolejne: MISSION_002...           ten sam kod współdzielony + src/mission_XXX
```

Nowa misja = nowy plik projektu, pozycja w `Config/Places.luau` i `Config/Missions.luau`, a do tego moduł mapy i zagadki. Hub nie wymaga zmian w kodzie.

## 3. Foldery i moduły

```
src/
├─ shared/                     → ReplicatedStorage.Shared
│  ├─ Net.luau                 nazwy i tworzenie RemoteEvents
│  ├─ Strings.luau             teksty PL/EN
│  ├─ Config/
│  │  ├─ Game.luau             strojenie (czasy, zasięgi, limity)
│  │  ├─ Places.luau           ID miejsc
│  │  ├─ Missions.luau         katalog misji
│  │  ├─ Palette.luau          kolory
│  │  ├─ Lighting.luau         presety oświetlenia
│  │  └─ Sounds.luau           bank dźwięków
│  ├─ Core/                    CZYSTA logika, testowana w Lune
│  │  ├─ Rng.luau              powtarzalny generator
│  │  ├─ Seats.luau            siatka siedzeń, etykiety
│  │  ├─ Puzzle.luau           generowanie zagadki z seed i take
│  │  ├─ Flow.luau             maszyna stanów misji
│  │  ├─ Framing.luau          czy punkt jest w kadrze
│  │  ├─ Graph.luau            węzły i BFS
│  │  ├─ Registrar.luau        reguły Kadrowego
│  │  ├─ Tape.luau             taśmy, walidacja ścieżek
│  │  ├─ Party.luau            drużyny
│  │  ├─ Progress.luau         schemat i scalanie zapisu
│  │  ├─ RateLimit.luau        token bucket
│  │  ├─ Take.luau             warianty podejść
│  │  └─ Layout.luau           pozycje mapy misji jako dane
│  └─ World/
│     ├─ Build.luau            pomocnicy geometrii
│     ├─ Sets.luau             meble wielokrotnego użytku
│     └─ LightingApply.luau    nałożenie presetu
├─ server_common/              → ServerScriptService.Common
│  ├─ Loader.luau              init/start serwisów
│  └─ PlayerData.luau          DataStore z retry i scalaniem
├─ client_common/              → ReplicatedStorage.ClientCommon
│  ├─ Loader.luau
│  ├─ Ui.luau                  fabryka elementów UI
│  ├─ Input.luau               PC, dotyk, kontroler
│  ├─ LensView.luau            wizjer i warstwa taśmy
│  ├─ PromptText.luau          tłumaczenie promptów na języku klienta
│  └─ AudioDirector.luau       warstwy i reżyser ciszy
├─ hub/
│  ├─ server/                  → ServerScriptService.Hub
│  │  ├─ Boot.server.luau
│  │  └─ Services/ HubWorld, HubDressing, Parties, Teleports, Archive
│  └─ client/                  → StarterPlayerScripts.Hub
│     ├─ Boot.client.luau
│     └─ Controllers/ Intro, Terminal, ArchiveUi, StaffRoom, LockerUi
└─ mission/
   ├─ server/                  → ServerScriptService.Mission
   │  ├─ Boot.server.luau
   │  └─ Services/ MissionWorld, MissionAnnex, MissionDressing, Session, Lens, Tapes, Puzzles, RegistrarAi, OffFrame, Comms
   └─ client/                  → StarterPlayerScripts.Mission
      ├─ Boot.client.luau
      └─ Controllers/ Audience, CodeCards, Keypad, Hints, OmenDirector, SeatPlaques, RegistrarView, Viewfinder, Playback, Hud, Silence, OffFrameView, EndTape
tests/                         specyfikacje Lune
lune/test.luau                 runner
scripts/check.py               bramki jakości
```

### Odpowiedzialności serwisów misji

| Serwis | Odpowiada za | Zależy od |
|---|---|---|
| `MissionWorld` | Buduje mapę, prompty, oświetlenie | Layout, Sets |
| `Session` | Seed, take, roster, Flow, cel, koniec misji, teleport | Flow, Puzzle, Take, PlayerData |
| `Lens` | Stan kamer, walidacja, framing | Framing, RateLimit |
| `Tapes` | Nagrywanie, odtwarzanie, zliczanie | Tape, Lens, RegistrarAi |
| `Puzzles` | Siedzenia, haki, projektor, drzwi, rejestr, dzwonek | Puzzle, Session, RegistrarAi, Lens |
| `RegistrarAi` | Pętla Kadrowego | Registrar, Graph, Lens, OffFrame |
| `OffFrame` | Wycięcie, ratunek, koniec taśmy | Lens, Session |
| `Comms` | Komunikaty, pukanie, latarka | RateLimit |

Przepływ zależności jest jednokierunkowy, a serwisy pobierają się przez loader w `start()`, nie przy ładowaniu modułu, dzięki czemu nie ma pętli `require`.

## 4. Kontrakt sieciowy (`Net.luau`)

| Event | Kierunek | Dane | Walidacja na serwerze |
|---|---|---|---|
| `LensState` | C→S | `raised: bool, camCF: CFrame?` | Typ, limit 8/s, kamera ≤ 14 studs od głowy, gracz nie jest wycięty |
| `RecordStart` | C→S | – | Limit, kamera w górze, ma taśmy |
| `RecordStop` | C→S | `track: {{x,y,z,lx,ly,lz}}` | ≤ `MaxSamples`, liczby skończone, pierwszy punkt blisko gracza, prędkość < limit |
| `PlayTape` | C→S | `tapeId: number` | Właściciel, limit, nie trwa inne odtworzenie |
| `TapePlay` | S→C | klip + `visibleTargets`, liczba odtworzeń | – |
| `PlayEnded` | C→S | `tapeId` | Właściciel |
| `QuickComm` | C→S | `kind: number` | Zakres 1–4, limit |
| `Knock` | C→S | – | Tylko wycięty, limit |
| `FlashlightToggle` | C→S | – | Limit |
| `SessionState` | S→C | `{phase, objective, reels, roster, take, seed...}` | – |
| `Notify` | S→C | `key, args` | – |
| `RegistrarEvent` | S→C | `kind` (`preJump`, `jump`, `reach`, `cut`) | – |
| `EndMission` | S→C | wynik | – |
| `CodeEntry` | C→S | `{d, d, d}` | Limit, zasięg panelu, faza Power, porównanie na serwerze |
| `CodeDigits` | S→C | cyfry przydzielone temu graczowi | – |
| Hub: `LockerAction` | C→S | `action, id` | Biała lista, ramka istnieje i jest odblokowana, limit |
| Hub: `PartyAction` | C→S | `action, arg` | Biała lista akcji, typ, limit |
| Hub: `PartyState` | S→C | lista drużyn, moja drużyna | – |
| Hub: `TeleportStatus` | S→C | etap, błąd | – |
| Hub: `IntroAction` | C→S | `step` | Biała lista |
| Hub: `DocsState` | S→C | dokumenty | – |

Klient nie ogłasza sukcesu. Serwer sam liczy framing i sprawdza stan zagadki.

## 5. Bezpieczeństwo

- **Zagadka autorytatywna:** cele zagadki są tylko na serwerze. Klient dostaje cel, gdy nagrany ślad rzeczywiście go obejmuje.
- **Prompty:** obsługiwane przez `ProximityPrompt.Triggered` na serwerze i dodatkowo sprawdzamy odległość.
- **Rate limit:** token bucket na gracza i typ zdarzenia (`Core/RateLimit`).
- **Framing:** ścieżka kamery z klienta może zostać sfałszowana. Limity (bliskość głowy, prędkość) ograniczają szkody. Oszust może najwyżej przedłużyć sobie widok lub zamrozić Kadrowego, ale nie zdobędzie nagród poza ukończeniem misji.
- **Znany kompromis:** ruch graczy pozostaje po stronie klienta (standard Roblox). Noclip przez ukrytą ścianę jest możliwy, więc rejestr sprawdza fazę misji, a nagroda wymaga przejścia pełnego Flow po stronie serwera.
- **Teleport:** dane z `TeleportData` przechodzą białą listę. Nagrody nie opierają się na tych danych.
- **Dane:** gracz nie może zapisać dowolnej wartości. Wszystkie zmiany w `PlayerData` wywołuje serwer.

## 6. Zapis

**DataStore `Progress_v1`, klucz `u_<UserId>`:**
```lua
{ v = 1, missions = {M001 = true}, docs = {doc_list = true},
  achievements = {}, cosmetics = {},
  stats = {completions = 0, replays = 0, cuts = 0, bestTime = 0},
  flags = {introDone = true} }
```

**Dane sesyjne (tylko w pamięci):** taśmy, szpule, faza misji, pozycja Kadrowego.

**Wyścig przy teleporcie:** hub może zapisać dane po tym, jak misja już je wczytała. Zamiast blokad sesji używamy **scalania monotonicznego**: zbiory są sumowane, statystyki wyższe wygrywają, a `UpdateAsync` łączy zapis z tym, co jest w chmurze. Postęp może tylko rosnąć, więc starszy zapis go nie cofnie. Gra nie ma waluty, handlu ani niczego, co wymagałoby transakcji. **Przy dodaniu ekonomii kosmetycznej (Robux) trzeba będzie rozważyć blokadę sesji lub ProfileStore.**

**Statystyki-liczniki** liczymy jako delty sesji dodawane przy zapisie, by nie sumować ich podwójnie.

**Kiedy zapisujemy:** wyjście gracza, przed teleportem, koniec misji, autozapis co 180 s, `BindToClose`. Trzy próby z wykładniczą przerwą. W Studio bez dostępu do API działamy w pamięci z ostrzeżeniem.

## 7. Multiplayer i teleport

```
Hub                                               Mission
PartyAction(create/join/ready/start)
  → Core.Party (walidacja)
  → odliczanie 5 s (można przerwać)
  → PlayerData.save(wszyscy)
  → TeleportOptions.ReservedServerId = GUID
  → SetTeleportData({mission, seed, partyId, v})
  → TeleportAsync(placeId, players, options) ──▶ PlayerAdded → GetJoinData()
     │ pcall: błąd → retry (3×, 1/3/9 s)         → biała lista pól
     │ TeleportInitFailed → retry z options      → czeka na oczekiwanych max 25 s
     └ ostateczna porażka: status do klientów    → Session.begin()
  → MemoryStore rejoin_<userId> = {GUID, placeId}, TTL 30 min

Koniec misji:
  → PlayerData.save(wszyscy)
  → czeka na obejrzenie taśmy (max 40 s)
  → TeleportAsync(hubPlaceId, players)
  → czyści klucze rejoin
```

| Sytuacja | Zachowanie |
|---|---|
| Ktoś opuści drużynę przed startem | Odliczanie jest anulowane, lider dziedziczony |
| Lider wyjdzie | Następna osoba staje się liderem |
| Teleport nieudany | 3 próby, potem status i powrót do panelu |
| Część drużyny nie dotarła | Po 25 s misja startuje z tymi, co są |
| Rozłączenie w misji | Postać znika. Jeśli wszyscy wycięci lub nikt nie został, koniec |
| Powrót po rozłączeniu | Hub odczytuje klucz i proponuje powrót tym samym `ReservedServerId` |
| Serwer misji pusty | `game:BindToClose` zapisuje; serwer gaśnie sam |
| Studio | Teleport jest pomijany, hub pokazuje komunikat, misja działa w trybie dev |

Znajomi: `PromptGameInvite` zaprasza do huba. Dalej trafiają na listę drużyn, o ile są na tym samym serwerze huba. **Ograniczenie VS:** dołączenie przez dowolny inny serwer huba wymaga globalnej listy (MemoryStore) i jest poza slice.

## 8. AI Kadrowego

`Core/Registrar` to czysta logika wywoływana stałym krokiem 0,25 s. `RegistrarAi` zbiera wejścia (kto kadruje, gdzie są gracze) i wykonuje wyjścia (zdarzenia, teleport kotwicy).

```
framed? → timer stoi, rejestracja++ dla patrzącego
        → 6 s → zarejestrowany = cel priorytetowy
nie     → timer--
timer < 2 s → zdarzenie preJump (cisza) raz na skok
timer ≤ 0   → krok BFS do najbliższego celu, reset timera
gracz ≤ promień po skoku → reach (1,5 s) → jeśli nie kadrowany: cut
po cut → powrót do odległego węzła, karencja
replay  → natychmiastowy krok w stronę oglądającego
```

**Bez PathfindingService.** Kadrowy nie chodzi, więc graf węzłów jest prostszy, tańszy i przewidywalny. Do późniejszych przeciwników (Dubler) użyjemy pathfindingu.

**Wygląd po stronie klienta:** kotwica na serwerze to niewidzialna część z atrybutem. `RegistrarView` buduje lokalny model i co klatkę dostosowuje długość szyi tak, by głowa była zawsze nad krawędzią kadru.

## 9. Warstwa taśmy i odtworzenie

- `Audience` buduje 192 sylwetki stale obecne w `Workspace` i pokazuje je przez `LocalTransparencyModifier` w wizjerze lub finale.
- Stan warstwy wynika z: czy jest kamera, czy trwa odtworzenie, faza misji, wycięcie.
- **Odtworzenie:** `Camera.CameraType = Scriptable`, interpolacja `CFrame` między próbkami, duchy graczy jako sylwetki, obrót odwróconych osób, Kadrowy w `Tape.ghostDistance(replays)`.
- Ruch ciała jest zablokowany przez `ContextActionService` w trakcie odtworzenia, by nie sterować niewidzianą postacią.

## 10. Wydajność

Budżet (do pomiaru na telefonie, jeszcze niezmierzone):

| Element | Części | Uwagi |
|---|---|---|
| Struktura misji | ~250 | Ściany, podłogi |
| Krzesła | ~576 | Po 3 części, niekolidujące poza siedziskiem |
| Widownia (klient) | ~576 | Tylko w wizjerze |
| Światła | ≤ 20 | Bez cieni na większości |
| Efekty | Bloom, CC, Atmosphere | DoF tylko na odtworzeniu |

**Plan B, gdy się zatnie:** jeden `MeshPart` na rząd z Blendera to 16 razy mniej części.

## 11. Testy

| Warstwa | Narzędzie | Co obejmuje |
|---|---|---|
| Czysta logika | Lune | Core |
| Składnia i drzewo | `rojo build` | Oba projekty |
| Styl | selene, stylua | Całe `src` |
| Integracja | Playtest Studio przez MCP | Solo |
| Multiplayer, teleport, zapis w chmurze | **Wymaga publikacji** | Nie da się w Studio |
