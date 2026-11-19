# 09. GDD v2: HEADCOUNT, „The Extra”

Wersja 0.1, 2026-11-19. Ten dokument zmienia główny tryb gry. Świat, fabuła i Misja 001 z `02_GDD.md` zostają, ale jako tryb fabularny (§10), a nie rdzeń.

Oznaczenia: **[PROTO]** wchodzi do prototypu, **[START]** do premiery, **[PÓŹNIEJ]** po premierze. Wszystkie liczby to wartości startowe do strojenia na testach, nie pomiary.

## 0. Dlaczego zmiana

| Stary model (`02_GDD.md`) | Co dziś nagradza Roblox |
|---|---|
| Ręcznie zrobiona misja na 15–25 minut. Po rozwiązaniu zagadki nie ma po co wracać | Od czerwca 2026 algorytm rekomendacji patrzy na 28 dni i osobno mierzy dzień 1, dni 2–7 i dni 8–28. Treść, która się kończy, przegrywa |
| Wolny start: pokój intro, dokumenty do czytania | Nowy sygnał: szybkie wyjście z pierwszej sesji (*first play bounce*) liczy się na minus |
| Wymaga drużyny znajomych (1–4) | Większość graczy wchodzi sama, na publiczny serwer |
| Brak waluty, progresji i kolekcji | Gracze wracają dla kolekcji, rang i rzadkich zdobyczy |
| Monetyzacja prawie zerowa | Wydatki są osobnym sygnałem w rekomendacjach |

**FAKT:** w sierpniu 2026 Roblox ograniczył gry nagradzające bezmyślne scrollowanie (Steal An Egg został zdjęty i wrócił bez feedu wideo). Retencja ma wynikać z uczciwej pętli, nie z dark patterns.

**INTERPRETACJA:** Najtrwalsze gry społeczne na Robloxie opierają się na prostej roli, krótkiej rundzie, publicznym serwerze i kolekcji kosmetyki. Przykłady: ukryty zabójca wśród graczy (gatunek Murder Mystery) i asymetryczny horror (Forsaken). Nasza mechanika „kamera pokazuje to, czego nie widzi oko” pasuje do takiego formatu lepiej niż do misji fabularnej.

**Co zostaje z poprzedniego GDD:** kamera ujawniająca prawdę, koszt informacji, wycięcie z kadru zamiast śmierci, ratunek kadrem, świat Biura Ciągłości i estetyka domu kultury z lat 80.

## 1. Obietnica

**Jednym zdaniem:** Jeden z was nie jest człowiekiem. Gołym okiem wygląda jak każdy gracz. W kamerze widać prawdę.

**Hak w tytule:** na liście obecności jest was ośmioro, a licznik pokazuje 9.

**Statysta (EN: The Extra):** w filmie statysta to osoba w tle. Tu to ten jeden nadliczbowy. Jego prawdziwa forma to sylwetka Kadrowego: bardzo wysoki garnitur, głowa zawsze poza górną krawędzią kadru.

### Filary
1. **Kamera mówi prawdę.** Oko widzi ludzi, a wizjer widzi, kto nim nie jest.
2. **Prawda kosztuje.** Z podniesioną kamerą idziesz wolniej, widzisz wąsko i zużywasz baterię. Kto ogląda taśmę, stoi bezbronny.
3. **Prawie jak twój znajomy.** Statysta wygląda jak każdy, a po pierwszym wycięciu może wyglądać jak ktoś, kogo znasz.
4. **Każda runda kończy się historią.** Ujawnienie, taśma rundy, „to byłem ja!”.

### Moment do pokazania (miniatura, TikTok)
Idziesz korytarzem za kolegą. Podnosisz kamerę i w wizjerze kolega ma ponad dwa metry, a nad kołnierzem nie ma nic. Na czacie ten sam kolega pisze, że jest w piwnicy.

### Grupa i etykieta
9+, cel Maturity **Mild**. Bez krwi; wycięcie to efekt taśmy (rozjechany kadr, szum), nie przemoc. Gracze znający gatunek ukrytego zabójcy od razu rozumieją role. Wszystko poza tym jest nasze: kamera, wycięcie zamiast zabijania, brak broni, przebrania i świat.

## 2. Runda

### 2.1 Parametry startowe
| Parametr | Wartość |
|---|---|
| Graczy na serwerze | 6–12 (poniżej 6 tryb Polowanie, §2.12) |
| Przerwa w lobby | 20 s |
| Intro rundy | 10 s: kamera po sali, lista obecności, licznik „8… 9” |
| Taśma (czas rundy) | 5:00, skracana zadaniami |
| Ujawnienie i wyniki | 25 s |
| Mapa | głosowanie z 3 losowych |

### 2.2 Role
| Rola | Ilu | Wyposażenie | Cel |
|---|---|---|---|
| **Asystent** (Assistant) | reszta | kamera, 2 kasety, latarka, krótkofalówka | przetrwać do końca taśmy, uzupełnić listę obecności, pomóc zdemaskować Statystę |
| **Reżyser** (Director) | 1 | jak asystent + **klaps** | zdemaskować Statystę klapsem |
| **Statysta** (The Extra) | 1 (2 przy 11–12 graczach [PÓŹNIEJ]) | prawdziwa forma, zdolności | wyciąć wszystkich przed końcem taśmy |

Role są losowane. Szansa na Statystę i Reżysera rośnie z każdą rundą bez tej roli i spada do zera po jej otrzymaniu. **Szansę zdobywa się tylko graniem, nigdy za Robux.** Pierwsza runda w życiu gracza: zawsze Asystent.

### 2.3 Zasady Statysty
Cztery reguły, odkrywane w grze:
1. **Gołym okiem wygląda jak zwykły gracz.** Ma swój awatar, w rundzie nikt nie ma plakietek z imieniem, a jego prędkość chodu jest taka jak u asystentów.
2. **W każdym podniesionym wizjerze widać jego prawdziwą formę**, jeśli jest w kadrze i nie zasłania go ściana.
3. **Nie może wycinać, gdy ktokolwiek trzyma go w kadrze.** Wycięcie to dotyk i 0,6 s zamachu; jeśli w tym czasie trafi do czyjegoś kadru, zamach się przerywa.
4. **Wycięty zostawia po sobie wygląd.** Zdolność Dubel pozwala Statyście go „założyć”: od tej chwili wygląda jak wycięty gracz.

### 2.4 Reżyser i klaps [PROTO]
- Klaps działa na gracza w kadrze wizjera Reżysera, z odległości do 12 studów, po 0,8 s zamachu. Zamach widać i słychać („Scena pierwsza, ujęcie…”).
- **Trafiony Statysta:** pada „CIĘCIE!”, Statysta jest ujawniony wszystkim i wycięty z rundy. Asystenci wygrywają.
- **Trafiony asystent:** nic mu się nie dzieje, ale Reżyser zostaje zwolniony. Klaps wypada na podłogę, a w wizjerze świeci.
- Klaps po zwolnieniu lub wycięciu Reżysera może podnieść każdy asystent (przytrzymanie 3 s). Statysta go nie podniesie.
- To główne źródło napięcia: kto ma klaps, kto go podniesie i czy Reżyser się nie myli.

### 2.5 Kamera [PROTO]
| Właściwość | Wartość startowa | Po co |
|---|---|---|
| FOV w wizjerze | 52 (z `Config/Game` Lens.Fov) | wąskie pole, łatwo coś przeoczyć |
| Prędkość chodu z podniesioną kamerą | −40% | prawda kosztuje mobilność |
| Bateria | 30 s ciągłego wizjera, ładowanie 1 pkt/s przy opuszczonej | rytm: podnieś, sprawdź, opuść |
| Kadr | stożek 24°, zasięg 110 studów, bez ścian (`Core/Framing`) | jasna, sprawdzalna reguła |

W wizjerze widać też widownię z Misji 001 (siedzi w rzędach i patrzy na scenę) i omeny. To klimat, nie fałszywe tropy: widownia siedzi, a Statysta zawsze stoi.

### 2.6 Taśmy i projektor (głębia dla lepszych graczy) [START]
- Nagranie do 10 s, 2 kasety na rundę, plus pudełko kaset na mapie.
- **Odtworzenie w kamerze** pokazuje nagrany kadr z prawdziwymi formami z chwili nagrania. W tym czasie stoisz bezbronny.
- **Projektor** (jeden na mapie): włożona kaseta leci na dużym ekranie, a wszyscy w sali widzą to samo nagranie.
- Na taśmie Statysta ma prawdziwą formę, ale nad nią widnieje imię z listy obecności osoby, którą udawał w chwili nagrania. Taśma mówi więc „to był wygląd Kuby”, a drużyna wie z listy, czy Kuba był już wycięty.
- **Na żywo wiesz tylko ty, taśma to dowód dla wszystkich.** Statysta może twierdzić, że kłamiesz, dopóki nie pokażesz nagrania.
- **Koszt:** każde odtworzenie, w kamerze i na projektorze, daje Statyście jeden ładunek Skoku (§2.7). To zachowany filar z `02_GDD.md`: im częściej oglądasz, tym jest bliżej.
- Kasety odblokowują się od rangi 3, żeby pierwsza sesja była prosta.

### 2.7 Zdolności Statysty
| Zdolność | Działanie | Odnowienie | Uczciwy sygnał |
|---|---|---|---|
| **Cisza** [PROTO] | 5 s zakłóceń wszystkich wizjerów w promieniu 30 studów | 35 s | zanik szumu tła na 1 s przed zakłóceniem |
| **Dubel** [START] | zakłada wygląd wyciętego gracza; 2 s przemiany, w tym czasie widoczny gołym okiem w prawdziwej formie | raz na każdego wyciętego | przemiana widoczna dla wszystkich w pobliżu |
| **Skok** [START] | przeskok do węzła grafu mapy, którego nikt nie kadruje | ładunki z odtworzeń taśm | migotanie świateł w miejscu startu i celu |

**Formy** [PÓŹNIEJ] zmieniają wygląd prawdziwej formy i dają jedną zdolność specjalną zamiast Skoku: Kadrowy (Skok), Bileter (gasi latarki w promieniu), Dubler (zostawia fałszywy ślad kroków). Zdolności form odblokowuje ranga, a nie zakup. Za Robux kupuje się tylko wygląd.

### 2.8 Wycięcie i powrót [PROTO]
- Wycięty widzi świat w chłodnym kolorze i zawsze widzi Statystę (z `OffFrameView`).
- Może chodzić i **pukać** (dźwięk w swojej pozycji, odnowienie 10 s). Pisze tylko na kanale czatu duchów, którego żywi nie widzą.
- **Ratunek** [START]: asystent trzyma wyciętego w kadrze przez 3 s i ten wraca. Każdego gracza można uratować raz na rundę. Statysta poluje na tych, którzy stoją w miejscu.

### 2.9 Lista obecności (zadania) [START]
- Na mapie jest 10–14 punktów obecności. Każdy to krótka czynność na 3–8 s: podpis na liście, sprawdzenie rzędu, zawieszenie płaszcza, bezpiecznik, taśma do magnetofonu. Wszystkie wzięte z interakcji Misji 001.
- Każde wykonane zadanie skraca taśmę o 10 s; pasek „TAPE REMAINING” jest stale widoczny.
- Gdy lista jest pełna, odzywa się dzwonek na scenie. Kto przytrzyma go 3 s, kończy rundę wygraną asystentów.
- Zadania zmuszają drużynę do rozdzielenia się, a to daje Statyście okazje.

### 2.10 Warunki końca
- **Asystenci wygrywają,** gdy: klaps trafi Statystę, taśma dobiegnie końca z co najmniej jednym niewyciętym asystentem albo ktoś zadzwoni dzwonkiem po pełnej liście.
- **Statysta wygrywa,** gdy wytnie wszystkich asystentów przed końcem taśmy.
- **Cel balansu:** Statysta wygrywa 40–50% rund. Liczymy to w analityce od pierwszego testu.

### 2.11 Przebieg rundy (8 graczy, około 5 minut)
| Czas | Co się dzieje | Emocja |
|---|---|---|
| 0:00–0:10 | Intro: kamera nad salą, lista obecności z 8 imionami, licznik pokazuje 9 | „Kto to?” |
| 0:10–1:00 | Rozbiegnięcie do zadań. Pierwsze podniesienia kamer na innych graczy | Podejrzliwość |
| 1:00–2:30 | Pierwsze wycięcie, zwykle kogoś, kto został sam. Na liście pojawia się przekreślenie | Szok, pierwsze oskarżenia |
| 2:30–3:30 | Dubel: ktoś „wraca” z piwnicy. Pierwsza taśma na projektorze | Paranoja, współpraca |
| 3:30–4:30 | Klaps (trafiony albo pudło i klaps na podłodze) | Szczyt |
| 4:30–5:00 | Ostatni asystenci przy dzwonku albo ostatnie wycięcie | Ulga albo porażka |
| po rundzie | Ujawnienie: „THE EXTRA WAS: ___”, taśma rundy, nagrody | „Jeszcze jedna” |

### 2.12 Mało graczy: tryb Polowanie [START]
Przy mniej niż 6 graczach albo w trybie solo nie ma ukrytej roli. Jest jawny Kadrowy sterowany przez dotychczasowe AI (`Core/Registrar`, `RegistrarAi`) z regułą z `02_GDD.md`: rusza się tylko wtedy, gdy nikt go nie kadruje. Zostają zadania, dzwonek i taśmy. Ten tryb służy też jako samouczek.

## 3. Pierwsza sesja
Cel: **pierwsza runda zaczyna się najpóźniej 45 s od wejścia.**

| Czas | Co się dzieje |
|---|---|
| 0:00 | Lobby (Hala Rejestrów). Jedno zadanie na ekranie: „Raise your camera” |
| 0:05 | Gracz podnosi kamerę i w hali widzi archiwistów, których gołym okiem nie ma (`Archivists` już istnieje) |
| ≤0:20 | Odliczanie do rundy i głosowanie na mapę |
| Runda 1 | Gracz jest zawsze Asystentem. Radio daje trzy krótkie, sytuacyjne wskazówki: „Raise your camera.”, „Something here isn't one of us.”, „Find the Director if you see it.” |
| Po rundzie | Ujawnienie, nagroda, pasek rangi i komunikat „Your chance to be The Extra: 14%” |

Zasady: na ekranie najwyżej jedna linia tekstu naraz, żadnych dokumentów do czytania w pierwszej sesji, a mechaniki odblokowują się z rangą (kasety od 3, projektor od 3, formy od 5).

## 4. Pętle i retencja

| Pętla | Czas | Co trzyma gracza |
|---|---|---|
| Sekundy | 5–10 s | podnieś kamerę, sprawdź, opuść, zdecyduj, komu ufasz |
| Runda | 5 min | rola, ujawnienie, taśma rundy, nagroda |
| Sesja | 5–8 rund | rosnąca szansa na rolę, XP do kolejnej rangi, 3 zadania dzienne |
| Dzień 1 | | pierwsza ranga, pierwsze odblokowanie, nagroda za powrót jutro |
| Dni 2–7 | | seria logowań z kosmetykiem w dniu 7, rotujący sklep, mapa tygodnia |
| Dni 8–28 | | sezon (Biuro Pass, 4–6 tygodni), kolekcje, rangi do 50, wydarzenia tygodniowe, nowa mapa co 2–3 tygodnie |

**Archiwum taśm** [START]: gracz zapisuje do 10 najlepszych taśm rundy. Lecą na telewizorze przy jego szafce w lobby i każdy może je obejrzeć.

## 5. Progresja i ekonomia [START]

- **Klatki (Frames):** waluta zdobywana w grze za udział w rundzie, wygraną, zadania, wycięcia (Statysta), demaskację (Reżyser) i **ryzykowne ujęcia**, czyli Statystę w kadrze przez ponad 3 s. To nagradza odwagę, a nie chowanie się.
- **Ranga (stopień służbowy):** 1–50, za XP. Odblokowuje mechaniki, zdolności form, ramki i tytuły.
- **Kolekcje:** skórki kamer i obiektywów, formy Statysty (wygląd), efekty wycięcia (co widać, gdy Statysta wycina), skórki klapsa, emotki, ramki wizjera (już są w `Config/Cosmetics`), plakietki.
- **Rzadkości:** zwykła, rzadka, epicka, legendarna i „Taśma Zero” (mityczna, tylko z wydarzeń).
- **Skąd się bierze:** sklep z dzienną rotacją (bezpośredni zakup: wiesz, co kupujesz), kasety-niespodzianki **wyłącznie za Klatki** i z jawnymi szansami, Pass, wydarzenia, osiągnięcia.
- **Wymiana między graczami** [PÓŹNIEJ]: tylko z pełną ochroną (podwójne potwierdzenie, historia, blokada dla nowych kont). W grach tego gatunku mocno podbija retencję, ale jest też źródłem oszustw, więc nie na start.

## 6. Monetyzacja

**Tak:** kosmetyka z §5, Biuro Pass (darmowa i płatna ścieżka, tylko kosmetyka i Klatki), serwery prywatne, kosmetyczne pakiety startowe, emotki.

**Nigdy:**
- płatna szansa na rolę,
- zdolności albo formy z innymi zasadami za Robux,
- płatne losowe przedmioty,
- ożywienia za Robux,
- jakakolwiek przewaga w rundzie.

**Dlaczego:** to gra PvP, a płatna przewaga niszczy zaufanie i retencję szybciej, niż zarabia. Płatne losowanie dla dzieci to dodatkowo ryzyko prawne. To kontynuacja zasady z `07_ROADMAP.md`.

## 7. Społeczność i viral
- **Ujawnienie** na koniec rundy: kamera najeżdża na Statystę i pokazuje napis „THE EXTRA WAS: ___”. Najmocniejsza chwila gatunku.
- **Taśma rundy** [START]: automatyczny klip 6–8 s z najlepszym momentem (ostatnie wycięcie, klaps, ratunek w ostatniej chwili), odtwarzany z zapisanych ścieżek ruchu. Przycisk „Save to Archive”. Klip w stylu VHS (`client_common/Vhs`) jest gotowy do nagrania telefonem.
- **Znajomi:** drużyna z lobby wchodzi razem na serwer (`Core/Party`), ale role losowane są niezależnie.
- **Zaproszenia** po rundzie: „Invite a friend: next round in 20 s” (`SocialService`).
- **Momenty dla twórców:** Dubel na przyjacielu, fałszywe oskarżenie, klaps w ostatniej sekundzie, pukanie ducha, któremu nikt nie wierzy.
- **Zwiastun** to zasada w jednym zdaniu plus scena z korytarza z §1.

## 8. Mapy
Wymagania dla każdej mapy: 8–12 graczy, 3–4 strefy, pętle zamiast ślepych zaułków, jeden projektor, jeden dzwonek, 10–14 zadań, węzły grafu dla Skoku i bota.

| Mapa | Źródło | Charakter | Kiedy |
|---|---|---|---|
| Dom Kultury „Jutrzenka” | adaptacja Misji 001 (foyer, sala, szatnia, kabina, piwnica) | duża sala i wąskie korytarze | [PROTO] |
| Kurs 17 | szkic z `08_MISJA_002.md` | ciasny autobus i przystanki, szybkie rundy | [START] |
| Pion | plan sezonu | klatka bloku, piętra, windy | [PÓŹNIEJ] |
| Turnus | plan sezonu | sanatorium, długie korytarze | [PÓŹNIEJ] |
| Archiwum 03 | lobby jako mapa | finał sezonu | [PÓŹNIEJ] |

## 9. Wydarzenia na żywo
- **Warunki rundy** z `Core/Conditions`: krótka taśma (krótsza runda), słabe żarówki, niespokojny Statysta (krótsze odnowienie Ciszy), uważna sala (widownia w wizjerze odwraca się w stronę Statysty, co jest podpowiedzią).
- **Wydarzenia tygodniowe:** „Full House” (dwóch Statystów), „Blackout” (tylko latarki), „Silent Night” (bez szumu tła, więc Cisza nie ma ostrzeżenia, ale trwa krócej).
- **Seans** [PÓŹNIEJ]: stałe wydarzenie raz w tygodniu o jednej godzinie, ogłaszane na wszystkich serwerach (`MessagingService`). Kadrowy pojawia się wtedy na każdym serwerze i można zdobyć mityczne nagrody. Taki termin daje skok liczby graczy, który algorytm widzi.
- **Sezony** (Halloween, zima): kosmetyka i jedna zmiana zasad na czas sezonu.

## 10. Tryb fabularny: Story Tapes
- Misja 001 „Zebranie” zostaje jako kooperacyjna misja dla 1–4 osób, uruchamiana z terminala w lobby (istniejący teleport i drużyny).
- Daje fabułę, dokumenty, unikalne ramki i materiał dla YouTuberów. Nie jest główną pętlą.
- Kolejne Story Tapes wychodzą raz na sezon jako wydarzenie.
- **Fabuła łączy oba tryby:** Statysta to luka w obsadzie Taśmy Zero, którą coś wypełnia. Biuro wysyła asystentów, żeby policzyli obecnych, a zawsze wychodzi o jednego za dużo.

## 11. Technika

### 11.1 Co zostaje z obecnego kodu
| Moduł | Rola w nowej grze |
|---|---|
| `Core/Framing`, `mission/server/Services/Lens` | serwer decyduje, kto jest w czyim kadrze: podstawa ujawniania Statysty i blokady wycięcia |
| `Core/Tape`, `Tapes`, `Playback` | kasety, dowody na projektorze, taśma rundy |
| `Core/Registrar`, `RegistrarAi`, `Core/Graph` | bot w trybie Polowanie, węzły Skoku |
| `OffFrame`, `OffFrameView` | wycięcie, duchy, ratunek |
| `Core/Conditions`, `Core/Omens`, `OmenDirector` | warunki rundy i klimat |
| `Core/StandIn` | Dubel i fałszywe ślady formy Dubler |
| `Core/Party`, `Parties`, `Teleports` | drużyny w kolejce, Story Tapes |
| `server_common/PlayerData`, `Core/Progress` | baza zapisu (do rozbudowy, §11.3) |
| `client_common/*` | UI, VHS, dźwięk, sterowanie, przyciski dotykowe |
| `shared/World/*`, `MissionWorld`, `MissionDressing`, `Core/Layout` | mapa 1 |
| `UsherAi` | przyszła forma Bileter i bot |
| `Archivists` (lobby) | pierwszy kontakt z kamerą |

### 11.2 Nowe serwisy
- `RoundService`: maszyna stanów Intermission → Intro → Play → Reveal → Results.
- `RoleService`: losowanie z rosnącą szansą, przechowywanie roli tylko na serwerze.
- `DisguiseService`: `Players:GetHumanoidDescriptionFromUserId` i `Humanoid:ApplyDescription` dla Dubla.
- `ClapperService`: klaps, upuszczanie i podnoszenie.
- `TaskService`: lista obecności, skracanie taśmy, dzwonek.
- `EconomyService` i `Inventory`: Klatki, przedmioty, zakupy (`MarketplaceService.ProcessReceipt`, idempotentnie).
- `QuestService`, `PassService`, `ShopService`: zadania dzienne, Pass, rotacja sklepu.
- `HighlightService`: wybór najlepszego momentu rundy z zapisanych ścieżek.
- `MapLoader`: mapy jako modele w `ServerStorage`, ładowane na rundę.
- Analityka: `AnalyticsService` (lejek pierwszej sesji, wyniki ról, czas rundy, wyjścia w trakcie).

### 11.3 Miejsca i zapis
- **Miejsce startowe = serwer rund** z małym lobby i mapą ładowaną na rundę. Publiczne rundy nie wymagają teleportu, więc odpada największe niesprawdzone ryzyko z obecnego slice.
- **Story Tapes** zostają w osobnym miejscu z istniejącym teleportem.
- **Zapis:** `Core/Progress` celowo nie ma waluty, bo dwa serwery mogą zapisywać ten sam klucz. Waluta do wydawania wymaga zapisu z blokadą sesji (`UpdateAsync` z identyfikatorem sesji albo blokada w `MemoryStoreService`). To trzeba zrobić przed ekonomią, nie po niej.

### 11.4 Bezpieczeństwo: rola musi być niewidoczna dla exploiterów
- **Serwer nigdy nie wysyła klientom, kto jest Statystą.** Klient dostaje polecenie „pokaż prawdziwą formę gracza X” tylko wtedy, gdy serwer potwierdzi kadr (`Lens`). Exploiter widzi więc Statystę tylko wtedy, gdy i tak by go zobaczył. Częstotliwość raportu kadru podnosimy z 5 do 10 Hz, żeby opóźnienie ujawnienia nie przekraczało 100 ms.
- **Statysta nie ma narzędzi (`Tool`) w postaci ani w plecaku**, bo te replikują się do wszystkich. Zdolności to wywołania serwera, a ich efekty są anonimowe.
- Taka sama prędkość, animacje i dźwięki kroków u Statysty i asystentów.
- Wycięcie, klaps i podnoszenie sprawdza serwer (dystans, kadr, czas). Klient tylko prosi.
- Wszystkie nagrody liczy serwer.

### 11.5 Wydajność
12 graczy, telefon minimum 30 FPS. Sprawdzanie kadru tylko dla podniesionych kamer, z wstępnym filtrem stożka przed raycastem. Najgorszy przypadek to 12 × 11 × 10 Hz, czyli około 1300 raycastów na sekundę, do zmierzenia na prototypie. Głębia ostrości tylko na mocniejszych urządzeniach.

## 12. Plan produkcji

### Etap 0: prototyp [PROTO], 2–3 tygodnie
Szare boksy, jedna mapa (sala, foyer i szatnia z Misji 001), role, zasady Statysty 1–3, Cisza, klaps, kamera z baterią, wycięcie bez ratunku, runda z timerem, ujawnienie. Bez ekonomii, kaset i Dubla.

Test: 3 sesje po 8 osób, w tym co najmniej połowa w wieku 10–14 lat.

**Kryteria przejścia** (nasze progi, nie benchmark rynkowy):
- co najmniej 60% testerów samo chce zagrać jeszcze raz,
- co najmniej 70% rozumie zasady po pierwszej rundzie,
- Statysta wygrywa 30–60% rund,
- średnia runda trwa 4–7 minut.

Jeśli prototyp nie przejdzie, poprawiamy rdzeń, zanim powstanie cokolwiek więcej. Ta sama zasada co w `07_ROADMAP.md`.

### Etap 1: alfa
Kasety i projektor, Dubel, Skok, ratunek, zadania i dzwonek, tryb Polowanie z botem, XP i Klatki z bezpiecznym zapisem, podstawowy sklep, analityka, telefon i kontroler.

### Etap 2: premiera [START]
Dwie mapy, Pass sezonu 1, zadania dzienne, taśma rundy i Archiwum taśm, ręcznie robione: prawdziwa forma Statysty, ikona i miniatury. Kwestionariusz Maturity (Mild), test obciążeniowy 12 graczy.

### Etap 3: gra na żywo
Mapa co 2–3 tygodnie, wydarzenie co tydzień, sezon co 4–6 tygodni, Story Tape co sezon, wymiana między graczami po stabilizacji.

### Cele po premierze (nasze, do kalibracji na danych)
Dzień 1 ≥ 25%, dzień 7 ≥ 8%, dzień 28 ≥ 3%, średnia sesja ≥ 25 minut. Odsetek szybkich wyjść z pierwszej sesji mierzymy od pierwszego dnia i obniżamy.

## 13. Ryzyka i otwarte pytania

| Ryzyko | Co robimy |
|---|---|
| Balans ról (największe) | analityka od prototypu, wszystkie liczby w `Config` |
| Za mało graczy na starcie | tryb Polowanie od 1 gracza, minimum 6 do trybu ukrytego |
| Za trudne dla 9–12-latków | mechaniki odblokowywane rangą, pierwsza runda zawsze jako Asystent |
| Exploiterzy odczytują rolę | §11.4: rola nigdy nie trafia do klienta |
| Duchy podpowiadają na Discordzie | akceptujemy; krótkie rundy i losowe role ograniczają szkody |
| Skojarzenie z gatunkiem ukrytego zabójcy | bierzemy gatunek, nie grę: inne role, kamera, brak broni, wycięcie, przebrania, własny świat |
| Nazwa | dostępności „HEADCOUNT” na Robloxie dalej nie sprawdzono |

**Do decyzji właściciela:**
1. 8 czy 12 graczy na serwer na start.
2. Czy Story Tapes są darmowe dla wszystkich, czy odblokowywane rangą.
3. Ile czasu dajemy prototypowi i kto go testuje.

## 14. Źródła
- Roblox Newsroom, zmiana algorytmu rekomendacji (czerwiec 2026): https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- DevForum, retencja 28-dniowa i first play bounce: https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- Roblox Docs, Discovery FAQ: https://create.roblox.com/docs/discovery-faq.md
- Notowania graczy, listopad 2026: https://endgametools.com/en/roblox/charts, https://rostats.io/charts
- Ograniczenia dla gier z doomscrollingiem: https://massivelyop.com/2026/08/29/roblox-clamps-down-on-gen-ai-brainrot-scrolling-games-after-steal-an-egg-goes-viral/
- Rynek horrorów 2026 (raport komercyjny, ostrożnie z liczbami): https://rolearn.dev/trend-reports/roblox-horror-genre-market-report-2026
- Konkurencja i referencje z `00_RESEARCH.md` pozostają aktualne.
