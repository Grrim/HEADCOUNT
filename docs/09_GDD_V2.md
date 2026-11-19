# 09. GDD v2: HEADCOUNT, kooperacyjne zmiany z kamerą (1–4 graczy)

Wersja 0.2, 2026-11-19. Ten dokument zmienia główny tryb gry. Świat, fabuła i Misja 001 z `02_GDD.md` zostają, ale jako tryb fabularny (§10), a nie rdzeń.

Oznaczenia: **[PROTO]** wchodzi do prototypu, **[START]** do premiery, **[PÓŹNIEJ]** po premierze. Wszystkie liczby to wartości startowe do strojenia na testach, nie pomiary.

**Historia wersji:** 0.1 (ten sam dzień) opisywała rundy 6–12 graczy z ukrytym graczem-potworem. Właściciel odrzucił ten kierunek, bo gra ma działać **solo i ze znajomymi**. Ukryta rola potrzebuje wielu obcych graczy, więc wypadła. Jej najmocniejszy obraz, czyli ktoś, kto wygląda jak twój znajomy, a w kamerze nim nie jest, został przeniesiony do przeciwnika Statysty (§2.3).

## 0. Dlaczego zmiana

| Stary model (`02_GDD.md`) | Co dziś nagradza Roblox |
|---|---|
| Ręcznie zrobiona misja na 15–25 minut. Po rozwiązaniu zagadki nie ma po co wracać | Od czerwca 2026 algorytm rekomendacji patrzy na 28 dni i osobno mierzy dzień 1, dni 2–7 i dni 8–28. Treść, która się kończy, przegrywa |
| Wolny start: pokój intro, dokumenty do czytania | Nowy sygnał: szybkie wyjście z pierwszej sesji (*first play bounce*) liczy się na minus |
| Brak waluty, progresji i kolekcji | Gracze wracają dla kolekcji, ulepszeń i rzadkich zdobyczy |
| Monetyzacja prawie zerowa | Wydatki są osobnym sygnałem w rekomendacjach |

**FAKT:** w sierpniu 2026 Roblox ograniczył gry nagradzające bezmyślne scrollowanie (Steal An Egg został zdjęty i wrócił bez feedu wideo). Retencja ma wynikać z uczciwej pętli, nie z dark patterns.

**INTERPRETACJA:** Trwałe horrory kooperacyjne na Robloxie (DOORS, Pressure, 99 Nights in the Forest) mają wspólny szkielet: wypad, który za każdym razem jest trochę inny, granie solo albo w małej drużynie, krótki start i postęp między wypadami. Nasza mechanika kamery pasuje do tego szkieletu, a ręcznie robiona misja nie.

**Co zostaje z poprzedniego GDD:** kamera ujawniająca prawdę, koszt informacji (odtworzenie przybliża Kadrowego), wycięcie z kadru zamiast śmierci, ratunek kadrem, Biuro Ciągłości i estetyka domu kultury z lat 80.

## 1. Obietnica

**Jednym zdaniem:** sam albo ze znajomymi zjeżdżasz coraz niżej do Archiwum i filmujesz to, czego nie widzi oko. Im lepsze nagranie, tym bliżej jest to, co nagrywasz.

### Filary
1. **Kamera mówi prawdę.** Oko widzi pusty korytarz i twojego kolegę. Wizjer widzi, co tam naprawdę stoi.
2. **Prawda kosztuje.** Z podniesioną kamerą idziesz wolniej, widzisz wąsko i zużywasz baterię. Kto ogląda taśmę, stoi bezbronny i przybliża Kadrowego.
3. **Jeszcze jedno piętro.** Po wykonaniu normy możesz wyjechać z łupem albo zjechać niżej po więcej. To główna decyzja każdej zmiany.
4. **Każda zmiana kończy się historią.** Taśma zmiany, ucieczka w ostatniej chwili, kolega, który nie był kolegą.

### Moment do pokazania (miniatura, TikTok)
Idziesz korytarzem za kolegą. Kolega pisze na czacie, że jest w piwnicy. Podnosisz kamerę, a ten przed tobą ma ponad dwa metry i nie ma głowy w kadrze. To scena z teasera (`10_TEST_FILMIKIEM.md`).

### Grupa i etykieta
9+, cel Maturity **Mild**. Bez krwi; wycięcie to efekt taśmy (rozjechany kadr, szum), nie przemoc.

## 2. Zmiana (jeden wypad)

### 2.1 Parametry startowe
| Parametr | Wartość |
|---|---|
| Graczy | 1–4 (solo, drużyna znajomych albo winda „dołącz do ekipy”, §7) |
| Pięter na zmianę | do 5 |
| Czas na piętrze | 2–4 min |
| Cała zmiana | 10–15 min |
| Start od wejścia do gry | najpóźniej 45 s (§3) |

### 2.2 Przebieg: winda, piętro, decyzja [PROTO]
1. **Winda Biura** zjeżdża na piętro −1. Biuro podaje **normę**: tyle punktów nagrań trzeba przywieźć, żeby zmiana była płatna.
2. **Piętro** składa się z 4–7 pomieszczeń wylosowanych z biblioteki modułów (§8). Na każdym są anomalie do sfilmowania, czasem zamknięte drzwi z kodem widocznym tylko na taśmie, i zagrożenia.
3. **Powrót do windy** daje wybór:
   - **W górę:** koniec zmiany, nagrania idą do ciemni, wypłata.
   - **W dół:** następne piętro z wyższym mnożnikiem (×1, ×1,5, ×2, ×3, ×4), rzadszymi anomaliami i groźniejszymi przeciwnikami.
4. **Porażka:** gdy wszyscy są wycięci, drużyna traci nagrania z tej zmiany, ale Biuro płaci 25% „wynagrodzenia zasadniczego” za to, co już było w windzie. Porażka boli, ale nie zeruje wieczoru.

Winda jest jedyną bezpieczną strefą: Kadrowy do niej nie wchodzi, a w środku ładuje się bateria. Szczegóły windy (licznik osób, zjazd, zamykanie drzwi, rekord głębokości) są w §2.8.

### 2.3 Zagrożenia
Każde ma jedną regułę i jeden sygnał. Gracz poznaje je stopniowo: nowe pojawiają się wraz z głębokością i rangą.

| Byt | Reguła | Sygnał | Od |
|---|---|---|---|
| **Kadrowy** (The Registrar) | widać go tylko w kamerze; rusza się wyłącznie wtedy, gdy nikt go nie filmuje; dotyk wycina z kadru | zanik szumu budynku przed skokiem | [PROTO], piętro −1 |
| **Statysta** (The Extra) | przybiera wygląd członka drużyny (solo: twój własny). Nie mówi i nie używa radia, macha „chodź za mną”. W kamerze widać prawdziwą formę. Kto da się dotknąć, zostaje wycięty | lista drużyny w radiu pokazuje, gdzie naprawdę jest każdy z was | [START], piętro −2 |
| **Bileter** (The Usher) | w ciemności widzi tylko światło latarki | szuranie butów, świecące okulary w kamerze | [START], ciemne piętra |
| **Dubler** | powtarza twoje ruchy sprzed 30 s; jeśli wejdzie w miejsce, w którym stoisz, wycina | twoje własne kroki za tobą | [PÓŹNIEJ], piętro −3 |

**Statysta to serce trybu kooperacyjnego.** Ze znajomymi rodzi naturalną paranoję („to ty stoisz w magazynie?”), a solo daje widok samego siebie idącego przed tobą. Sfilmowany z bliska przez 2 s zamiera i znika, a takie ujęcie jest warte najwięcej w całej grze. Ryzyko i nagroda w jednym.

Szkic Dublera (`Core/StandIn`) i Bileter (`UsherAi`) już istnieją w kodzie.

### 2.4 Kamera i ocena nagrań [PROTO]
| Właściwość | Wartość startowa | Po co |
|---|---|---|
| FOV w wizjerze | 52 (z `Config/Game`) | wąskie pole, łatwo coś przeoczyć |
| Prędkość chodu z podniesioną kamerą | −40% | prawda kosztuje mobilność |
| Bateria | 30 s ciągłego wizjera, ładowanie przy opuszczonej i w windzie | rytm: podnieś, sprawdź, opuść |
| Nagranie | do 10 s na kasetę, 3 kasety (więcej po ulepszeniu) | decyzja, co warto nagrać |

**Ocena ujęcia** (liczy serwer z zapisanej ścieżki kamery, `Core/Tape`):
- obiekt w środku kadru (`Core/Framing`),
- odległość: im bliżej, tym więcej,
- czas w kadrze, do 6 s,
- rzadkość anomalii,
- mnożnik piętra.

Wynik to od jednej do pięciu gwiazdek i tyle Klatek (§5). W ciemni po zmianie każde ujęcie ma krótką klatkę z oceną. Ta chwila to nagroda za ryzyko.

### 2.5 Taśmy: odtworzenie pokazuje więcej [START]
Zachowany filar z `02_GDD.md`:
- Odtworzenie w kamerze pokazuje rzeczy niewidoczne na żywo: kod na drzwiach, ślad, skąd przyszedł Statysta, anomalię, która była tylko przez chwilę.
- W tym czasie stoisz bezbronny.
- **Każde odtworzenie poza pierwszym na piętrze przybliża Kadrowego o jeden węzeł** (`Core/Registrar`).
- Część drzwi z kodem otwiera się tylko dzięki taśmie, więc odtwarzanie to decyzja, a nie opcja.

### 2.6 Wycięcie i powrót [PROTO]
- Wycięty widzi świat w chłodnym kolorze i zawsze widzi Kadrowego i Statystę (`OffFrameView`). Może chodzić i pukać, żeby podpowiadać drużynie.
- Jego kamera spada na podłogę razem z nagraniami. Kolega może ją podnieść i wywieźć windą.
- **Ratunek:** kolega trzyma wyciętego w kadrze przez 3 s i ten wraca.
- **Solo:** raz na zmianę można wrócić samemu, dochodząc w 30 s do znacznika przy windzie (to już działa w `OffFrame`). Drugie wycięcie kończy zmianę.

### 2.7 Przebieg zmiany (2 graczy, około 12 minut)
| Czas | Co się dzieje | Emocja |
|---|---|---|
| 0:00–0:20 | Winda zjeżdża, Biuro podaje normę | Oczekiwanie |
| 0:20–3:00 | Piętro −1: pierwsze anomalie w kamerze, pierwsze nagrania. Kadrowy w oddali | Ciekawość, pierwszy dreszcz |
| 3:00–4:00 | Norma prawie zrobiona, Kadrowy bliżej. Powrót do windy: w górę czy w dół? | **Decyzja** |
| 4:00–7:00 | Piętro −2: ciemniej, Statysta. „Gdzie jesteś?” „W magazynie”. „To kto stoi obok mnie?” | Paranoja |
| 7:00–9:00 | Drzwi z kodem: trzeba odtworzyć taśmę, a Kadrowy podchodzi | Ryzyko |
| 9:00–11:00 | Jeden wycięty, ratunek kadrem albo kamera kolegi podniesiona z podłogi | Szczyt |
| 11:00–12:00 | Ucieczka do windy, drzwi się zamykają, w szparze stoi Kadrowy | Ulga |
| po zmianie | Ciemnia: ocena ujęć, wypłata, taśma zmiany | „Jeszcze jedna” |

### 2.8 Winda
Winda to jedyne bezpieczne miejsce w grze i jedyna droga między piętrami (§2.2). Jest też sceną, a nie tylko przejściem.

**Licznik osób** [START]
- Nad drzwiami świeci tabliczka „PERSONS: 2”. Pokazuje prawdziwą liczbę postaci w kabinie, łącznie ze Statystą.
- Od piętra −2 Statysta może wsiąść razem z drużyną, wyglądając jak jeden z was. Gołym okiem wszystko się zgadza, poza tabliczką. W kamerze widać, kto jest za dużo.
- **Uczciwa reguła:** w windzie Statysta nikogo nie wycina. Sfilmowany w kabinie przez 2 s znika, a takie ujęcie jest wyjątkowo cenne. Jeśli nikt go nie sfilmuje, wysiada z wami i chodzi za drużyną po następnym piętrze.
- Solo: jedziesz sam, a tabliczka pokazuje „2”. To nazwa gry w jednej scenie.

**Zjazd jako krótkie wydarzenie** [PROTO: wersja podstawowa]
- Zjazd trwa 10–15 s. Daje oddech między piętrami i czas na ładowanie baterii.
- Każdy zjazd losuje jedno drobne zdarzenie bez zagrożenia: mrugające światło, kroki na dachu kabiny, głos w głośniku Biura, wskaźnik pięter, który na chwilę pokazuje piętro, którego nie ma (np. −13).
- Zdarzenia korzystają z istniejącego systemu omenów (`Core/Omens`, `OmenDirector`).

**Zamykanie drzwi** [PROTO]
- Drzwi zamykają się powoli, przez około 4 s. Kadrowy, który dobiegnie do windy, staje w szparze.
- Dopóki ktoś trzyma go w kadrze, nie wejdzie. Gdy drzwi się domkną, odjeżdżacie.
- To zamierzony najczęstszy moment do nagrania: ucieczka w ostatniej sekundzie.

**Rekord głębokości** [START]
- Najgłębsze piętro, z którego gracz wrócił, jest w profilu i na tablicy w lobby („DEEPEST RETURN: −7”).
- Liczy się tylko powrót windą, nie samo zejście. Rekord nagradza dobrą decyzję przy windzie, a nie brawurę.

**Każde piętro wygląda inaczej** [START]
- Im głębiej, tym dziwniej. W lokacji Dom Kultury:
  - −1: jasny, zwyczajny dom kultury,
  - −2: wieczór, część świateł nie działa,
  - −3: magazyny taśm,
  - −4: korytarze, w których meble stoją pod sufitem,
  - −5: coś, co wygląda jak lobby gry, tylko źle (zapowiedź finału sezonu z `02_GDD.md`).
- Głębokość zmienia też oświetlenie, dźwięk tła i pulę anomalii, więc gracz czuje zejście bez czytania liczb.

## 3. Pierwsza sesja
Cel: **pierwsza zmiana zaczyna się najpóźniej 45 s od wejścia.**

| Czas | Co się dzieje |
|---|---|
| 0:00 | Lobby (Hala Rejestrów). Jedno zadanie na ekranie: „Raise your camera” |
| 0:05 | Gracz podnosi kamerę i widzi archiwistów, których gołym okiem nie ma (`Archivists` już istnieje) |
| ≤0:45 | Winda „Solo” albo „Dołącz do ekipy”, zjazd |
| Zmiana 1 | Skrócona: jedno piętro, tylko Kadrowy, anomalia gwarantowana tuż przy windzie. Radio daje trzy krótkie wskazówki: „Raise your camera.”, „Film it. Closer is better.”, „It only moves when nobody's filming.” |
| Po zmianie | Pierwsza wypłata i **od razu pierwsze ulepszenie do kupienia** (np. dłuższa bateria). Przycisk „Next shift” |

Zasady: na ekranie najwyżej jedna linia tekstu naraz, żadnych dokumentów do czytania w pierwszej sesji, nowe byty i mechaniki (taśmy, Statysta) odblokowują się stopniowo.

## 4. Pętle i retencja

| Pętla | Czas | Co trzyma gracza |
|---|---|---|
| Sekundy | 5–10 s | podnieś kamerę, sprawdź, nagraj albo uciekaj |
| Piętro | 2–4 min | norma, anomalie, decyzja przy windzie |
| Zmiana | 10–15 min | ciemnia, gwiazdki, wypłata, taśma zmiany |
| Sesja | 3–5 zmian | następne ulepszenie, nowe piętro rekordu, 3 zadania dzienne |
| Dzień 1 | | pierwsze ulepszenia, pierwszy rzadki wpis w Archiwum, nagroda za powrót jutro |
| Dni 2–7 | | seria logowań z kosmetykiem w dniu 7, dzienny modyfikator nocy, tygodniowa anomalia |
| Dni 8–28 | | sezon (Biuro Pass, 4–6 tygodni), kolekcja Archiwum, rangi do 50, nowa lokacja co 3–4 tygodnie, Story Tape co sezon |

## 5. Progresja i ekonomia [START]

- **Klatki (Frames):** waluta zdobywana za nagrania, normę, głębokość i zadania dzienne.
- **Ulepszenia sprzętu:** bateria, obiektyw (zoom: lepsze ujęcia z bezpieczniejszej odległości), liczba kaset, noktowizja, latarka, **statyw** (zostawiona kamera trzyma Kadrowego w kadrze przez 20 s: ratunek dla graczy solo).
  - Każde ulepszenie ma 3–5 poziomów i wyraźny limit. Ma zmieniać sposób gry, a nie robić z gracza nieśmiertelnego.
  - To tryb PvE, więc moc za grę jest w porządku. Mocy za Robux nie sprzedajemy (§6).
- **Ranga (stopień służbowy):** 1–50 za XP. Odblokowuje głębsze piętra, lokacje, tytuły i ramki.
- **Archiwum anomalii:** kolekcja z rzadkościami (zwykła, rzadka, epicka, legendarna, „Taśma Zero”) i procentem ukończenia. Najlepsze ujęcie każdej anomalii zostaje w Archiwum i można je obejrzeć.
- **Kosmetyka:** skórki kamer, ramki wizjera (już są w `Config/Cosmetics`), stroje Biura, plakietki, wystrój szafki w lobby.
- **Szafka z telewizorem** w lobby pokazuje najlepsze taśmy gracza. Każdy może je obejrzeć.

## 6. Monetyzacja

**Tak:** kosmetyka z §5, Biuro Pass (darmowa i płatna ścieżka, tylko kosmetyka i Klatki), serwery prywatne, kosmetyczne pakiety startowe.

**Nigdy:** ulepszenia sprzętu za Robux, płatne losowe przedmioty, przewaga, której nie da się zdobyć grą.

**Do decyzji właściciela:** płatne ożywienie w trakcie zmiany. DOORS je sprzedaje, a w PvE nikomu nie odbiera to wygranej. Zasada z `07_ROADMAP.md` mówi „nigdy”, więc domyślnie zostaje „nie”.

## 7. Granie ze znajomymi i z innymi
- **Solo:** winda „Solo” w lobby. Balans solo ma własne wartości (Kadrowy wolniejszy, statyw tańszy).
- **Znajomi:** drużyna z terminala w lobby (`Core/Party`, `Parties`) i zaproszenia (`SocialService`).
- **Dołącz do ekipy:** windy w lobby z miejscami 1–4, które odjeżdżają po 30 s albo po zapełnieniu. To dla graczy bez znajomych online i pomaga nowym zostać w grze.
- **Taśma zmiany** [START]: automatyczny klip 6–8 s z najlepszym momentem (ucieczka do windy, ratunek, Statysta z bliska), odtwarzany z zapisanych ścieżek. Przycisk „Save to Archive”. Wygląd VHS (`client_common/Vhs`) jest gotowy do nagrania telefonem.
- **Momenty dla twórców:** Statysta udający kolegę, pukanie ducha, decyzja „jeszcze jedno piętro”, drzwi windy zamykające się przed Kadrowym.

## 8. Lokacje i moduły
Lokacja to zestaw modułów pomieszczeń w jednym stylu. Generator składa z nich piętro według ziarna, zawsze z pętlami (bez ślepych zaułków) i z windą.

**Wymagania dla modułu:**
- wejścia na stałej siatce,
- własne węzły grafu dla Kadrowego (`Core/Graph`),
- 1–3 miejsca na anomalie,
- opcjonalnie drzwi z kodem albo ciemna strefa.

| Lokacja | Źródło | Charakter | Kiedy |
|---|---|---|---|
| Dom Kultury „Jutrzenka” | moduły z Misji 001 (foyer, sala, szatnia, kabina, piwnica, korytarz z kotarami) | duże sale i wąskie korytarze | [PROTO] |
| Zajezdnia (Kurs 17) | szkic z `08_MISJA_002.md` | autobusy, warsztaty, Dubler | [START] |
| Blok (Pion) | plan sezonu | klatki schodowe, mieszkania, windy | [PÓŹNIEJ] |
| Sanatorium (Turnus) | plan sezonu | długie korytarze, gabinety | [PÓŹNIEJ] |
| Archiwum 03 | lobby jako najgłębsze piętra | finał sezonu | [PÓŹNIEJ] |

Przy każdej lokacji powstaje 1–2 ręcznie zaprojektowane „pomieszczenia specjalne” (np. sala z pełną widownią w kamerze), żeby generator nie dawał wrażenia powtarzalności.

## 9. Wydarzenia na żywo
- **Modyfikator nocy** z `Core/Conditions`, jeden na dzień dla wszystkich: krótka taśma, słabe żarówki, niespokojny Kadrowy, uważna sala.
- **Anomalia tygodnia:** rzadka anomalia z większą szansą pojawienia się i własną nagrodą w Archiwum.
- **Seans** [PÓŹNIEJ]: stałe wydarzenie raz w tygodniu o jednej godzinie, ogłaszane na wszystkich serwerach (`MessagingService`). Na krótko otwiera specjalną lokację. Taki termin daje skok liczby graczy, który algorytm widzi.
- **Sezony** (Halloween, zima): kosmetyka, jedna lokacja albo byt na czas sezonu.

## 10. Tryb fabularny: Story Tapes
- Misja 001 „Zebranie” zostaje jako ręcznie zrobiona, fabularna zmiana dla 1–4 osób, odblokowywana rangą.
- Daje fabułę, dokumenty, unikalne ramki i materiał dla YouTuberów.
- Kolejne Story Tapes wychodzą raz na sezon.
- **Fabuła łączy oba tryby:** Biuro zjeżdża coraz niżej po materiał z Taśmy Zero. Na każdej liście obecności po zmianie jest o jedno nazwisko za dużo.

## 11. Technika

### 11.1 Co zostaje z obecnego kodu
Ten kierunek pasuje do obecnej architektury lepiej niż wersja 0.1: lobby i miejsce misji, drużyny 1–4 i teleport już są.

| Moduł | Rola w nowej grze |
|---|---|
| `hub/*` (lobby, `Parties`, `Teleports`, `Core/Party`) | lobby, drużyny, windy, teleport na zmianę |
| `Core/Framing`, `Lens` | kto co filmuje: ocena ujęć, zatrzymanie Kadrowego, ujawnienie Statysty |
| `Core/Tape`, `Tapes`, `Playback` | nagrania, ocena po stronie serwera, odtworzenia, taśma zmiany |
| `Core/Registrar`, `RegistrarAi`, `RegistrarView`, `Core/Graph` | Kadrowy bez zmian reguł |
| `OffFrame`, `OffFrameView` | wycięcie, duchy, ratunek, powrót solo |
| `UsherAi`, `Core/StandIn` | Bileter i Dubler |
| `Core/Conditions`, `Core/Omens`, `OmenDirector` | modyfikatory nocy i klimat |
| `server_common/PlayerData`, `Core/Progress` | baza zapisu (do rozbudowy, §11.3) |
| `client_common/*` | UI, VHS, dźwięk, sterowanie, przyciski dotykowe |
| `shared/World/*`, `MissionWorld`, `MissionDressing`, `MissionAnnex` | źródło modułów lokacji Dom Kultury |

### 11.2 Nowe
- `ShiftService`: maszyna stanów zmiany (winda, piętro, decyzja, ciemnia).
- `FloorGenerator` i biblioteka modułów: składanie piętra z ziarna, graf Kadrowego sklejany z węzłów modułów. Czysta logika w `shared/Core` z testami w lune, tak jak obecne moduły.
- `FootageScore`: ocena ujęć z oczyszczonej ścieżki kamery (`Tape.sanitize` już istnieje) i znanych serwerowi pozycji anomalii.
- `ExtraAi` (Statysta): wybór wyglądu (`Humanoid:ApplyDescription`), zachowanie „chodź za mną”, reakcja na kadr.
- `EconomyService`, `Upgrades`, `ArchiveCollection`: Klatki, poziomy sprzętu, kolekcja.
- `QuestService`, `PassService`: zadania dzienne i sezon.
- Windy matchmakingu w lobby: rozszerzenie `Parties` o publiczne drużyny.
- `HighlightService`: taśma zmiany.
- Analityka (`AnalyticsService`): lejek pierwszej sesji, decyzje przy windzie, głębokość, przyczyny wycięć, czas zmiany.

### 11.3 Zapis i teleport
- **Waluta wymaga zapisu z blokadą sesji.** `Core/Progress` celowo nie ma waluty, bo lobby i zmiana mogą zapisywać ten sam klucz po teleporcie. Rozwiązanie: `UpdateAsync` z identyfikatorem sesji albo blokada w `MemoryStoreService`, a wypłata zapisywana raz, na serwerze zmiany, przed teleportem do lobby. To trzeba zrobić przed ekonomią, nie po niej.
- **Teleport między lobby a zmianą nadal nie był testowany w prawdziwym kliencie** (`05_STATUS.md`). To pierwsze ryzyko techniczne do sprawdzenia w prototypie.

### 11.4 Bezpieczeństwo
- Ocena ujęć i wypłata liczona tylko na serwerze. Klient wysyła ścieżkę kamery, a serwer ją sprawdza (`Tape.sanitize`) i porównuje z pozycjami anomalii.
- Wycięcie, ratunek i podnoszenie kamery sprawdza serwer (dystans, kadr, czas).
- Zakupy przez `MarketplaceService.ProcessReceipt`, idempotentnie.

### 11.5 Wydajność
Telefon minimum 30 FPS. Moduły z prostej geometrii, światło lokalne, głębia ostrości tylko na mocniejszych urządzeniach. Sprawdzanie kadru tylko dla podniesionych kamer, z wstępnym filtrem stożka przed raycastem. Przy 4 graczach to niewielki koszt.

## 12. Plan produkcji

### Etap 0: prototyp [PROTO], 2–3 tygodnie
Szare boksy, lokacja Dom Kultury z 6–8 modułów, generator, 2 piętra, Kadrowy (obecne AI), kamera z baterią, ocena ujęć, norma, winda w górę i w dół (z prostym zjazdem i zamykaniem drzwi przed Kadrowym, §2.8), Klatki i 2 ulepszenia (zapis w pamięci, bez blokady sesji). Solo i 2 graczy.

Test: 3 sesje, w każdej solo i w parach, co najmniej połowa testerów w wieku 10–14 lat.

**Kryteria przejścia** (nasze progi, nie benchmark rynkowy):
- co najmniej 60% testerów samo chce zagrać kolejną zmianę,
- co najmniej 70% rozumie regułę Kadrowego po pierwszej zmianie,
- w co najmniej połowie zmian drużyna choć raz wybiera „w dół”, czyli decyzja przy windzie działa,
- średnia zmiana trwa 8–15 minut.

Jeśli prototyp nie przejdzie, poprawiamy rdzeń, zanim powstanie cokolwiek więcej. Ta sama zasada co w `07_ROADMAP.md`.

### Etap 1: alfa
Statysta, taśmy i drzwi z kodem, ratunek i podnoszenie kamery, Bileter, Archiwum anomalii, ekonomia z bezpiecznym zapisem, windy „dołącz do ekipy”, teleport sprawdzony na opublikowanej grze, telefon i kontroler, analityka.

### Etap 2: premiera [START]
Dwie lokacje, pełne drzewko ulepszeń, Pass sezonu 1, zadania dzienne, taśma zmiany, szafka z telewizorem, ręcznie robione: Kadrowy, Statysta, ikona i miniatury. Kwestionariusz Maturity (Mild).

### Etap 3: gra na żywo
Lokacja co 3–4 tygodnie, anomalia tygodnia, sezon co 4–6 tygodni, Story Tape co sezon.

### Cele po premierze (nasze, do kalibracji na danych)
Dzień 1 ≥ 25%, dzień 7 ≥ 8%, dzień 28 ≥ 3%, średnia sesja ≥ 25 minut. Odsetek szybkich wyjść z pierwszej sesji mierzymy od pierwszego dnia i obniżamy.

## 13. Ryzyka i otwarte pytania

| Ryzyko | Co robimy |
|---|---|
| Generator daje powtarzalne piętra | ręcznie robione moduły, pomieszczenia specjalne, modyfikatory nocy |
| Solo za trudne (reguła Kadrowego zakłada drugą osobę z kamerą) | własny balans solo, statyw jako wczesne ulepszenie, powrót solo raz na zmianę |
| Skojarzenie z DOORS (piętra, pokoje) | inny rdzeń: kamera, ocena nagrań, decyzja przy windzie, bez numerowanych drzwi i bez kolejnych pokoi w linii |
| Wyścig zapisu przy teleporcie | blokada sesji przed wprowadzeniem waluty (§11.3) |
| Teleport niesprawdzony | pierwszy test techniczny prototypu |
| Ciągła potrzeba treści | moduły i modyfikatory zamiast ręcznych misji; Story Tapes rzadko |
| Nazwa | dostępności „HEADCOUNT” na Robloxie dalej nie sprawdzono |

**Do decyzji właściciela:**
1. Płatne ożywienie w trakcie zmiany: tak czy nie (§6).
2. Czy drużyna może mieć więcej niż 4 osoby (np. 6).
3. Czy Story Tapes są darmowe, czy odblokowywane rangą.
4. Ile czasu dajemy prototypowi i kto go testuje.

## 14. Źródła
- Roblox Newsroom, zmiana algorytmu rekomendacji (czerwiec 2026): https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- DevForum, retencja 28-dniowa i first play bounce: https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- Roblox Docs, Discovery FAQ: https://create.roblox.com/docs/discovery-faq.md
- Notowania graczy, listopad 2026: https://endgametools.com/en/roblox/charts, https://rostats.io/charts
- Ograniczenia dla gier z doomscrollingiem: https://massivelyop.com/2026/08/29/roblox-clamps-down-on-gen-ai-brainrot-scrolling-games-after-steal-an-egg-goes-viral/
- Rynek horrorów 2026 (raport komercyjny, ostrożnie z liczbami): https://rolearn.dev/trend-reports/roblox-horror-genre-market-report-2026
- Konkurencja i referencje z `00_RESEARCH.md` pozostają aktualne.
