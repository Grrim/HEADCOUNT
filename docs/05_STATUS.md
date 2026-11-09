# 05. Status Vertical Slice

Stan na 2026-11-06, build 0.1. Oprawa to szary box z tymczasowymi dźwiękami.

## Wykonane

| Obszar | Stan |
|---|---|
| Dokumentacja (research, koncepcje, GDD, TDD, backlog) | Gotowa |
| Czysta logika (`Core/`) | Gotowa, 38 testów Lune |
| Misja 001: mapa, wizjer, widownia, taśmy, zagadka, Kadrowy, wycięcie, kulminacja, finałowa taśma | Działa solo w Studio |
| Hub: pokój startowy, intro, hala, terminal, drużyny, odliczanie, archiwum, ukryte drzwi | Działa solo w Studio |
| Teleport z ponawianiem, powrót po rozłączeniu, DataStore | **Napisane, nigdy nieuruchomione** |
| Przyciski dotykowe i kontroler | **Napisane, nieprzetestowane** |

## Testy faktycznie przeprowadzone

Bramki `scripts/check.py`: budowa obu miejsc, 38 testów logiki, selene, stylua. Wszystkie przechodzą.

Playtest przez Studio MCP, jeden gracz, klient na PC. Większość przebiegu sterowałem skryptem: pozycję i kamerę ustawiał skrypt testowy, prompty wyzwalałem przez `InputHoldBegin`. Serwer i jego walidacja działały normalnie. **Żaden człowiek nie przeszedł jeszcze misji od początku do końca w zwykły sposób**, więc nie znamy czasu przejścia ani tego, czy gra straszy i jest zrozumiała.

| Test | Wynik |
|---|---|
| Obie gry startują bez błędów skryptów | OK |
| Podniesienie kamery pokazuje widownię, opuszczenie ją chowa | OK |
| R/T: nagranie i odtworzenie klawiszami, walidacja na serwerze | OK |
| Taśma ujawnia tylko sfilmowane cele | OK dla taśmy obejmującej wszystkie 3 cele. Odrzucenie niesfilmowanych potwierdza tylko test logiki |
| Siedzenia, haki, projektor, film i wiązka | OK |
| Dwie błędne próby budzą Kadrowego i przesuwają go o krok | OK |
| Kadrowy skacze, ostrzega, sięga i wycina | OK |
| Widok poza kadrem, powrót przez znacznik w foyer | OK |
| Porażka: wszyscy poza kadrem | Działa, ale **po zmianie karencji na 75 s nie sprawdziłem wygaśnięcia** |
| Ściana blokuje bez kamery, przepuszcza z kamerą, faza rejestru | OK, w tym klawiszem W z kamerą w górze, po wcześniejszym odtworzeniu taśmy |
| Rejestr, kulminacja, dzwonek, finałowa taśma z awatarem i datą za tydzień | OK |
| Raport końcowy | OK dla porażki. Po sukcesie nieobejrzany |
| Migawka autobusu na końcu | Niezweryfikowana wizualnie |
| Hub: intro, drzwi, odrzucenie zapieczętowanej misji, podwójne tworzenie, gotowość, odliczanie, przerwanie, ukryty pokój | OK |
| Teksty polskie, układ terminala | OK na zrzucie 16:9 |
| 9 z 12 tymczasowych dźwięków: ładowanie | OK. **Nikt ich nie słuchał, więc nie oceniam brzmienia ani ciszy** |

Pomiar: ~1356 części z widownią, 60 FPS fizyki i 2,6 GB pamięci w Studio na mocnym PC. **To nie jest pomiar dla telefonu.**

## Czego nie testowałem

- Dwóch i czterech graczy, ratowania filmowaniem, ducha na taśmie, widoczności wyciętego kolegi.
- Telefonu, tabletu, kontrolera, przycisków dotykowych.
- Teleportu, serwerów zarezerwowanych, powrotu do huba, powrotu po rozłączeniu, zaproszeń.
- Zapisu w DataStore i scalania w chmurze. Logika scalania ma tylko testy Lune.
- Dubli 2 i 3 w grze: logika ma testy, wizualnie niesprawdzone.
- Zmian w lobby po misji (krzesła, tekst CRT), bo wymagają zapisu.
- Kolejne odtworzenia z Kadrowym coraz bliżej: dane sprawdzone testem logiki, obrazu nie oglądałem.

## Znane problemy

1. **Pierwsze ~10 s po wejściu obraz jest bardzo ciemny**, bo oświetlenie dopiero się przelicza po zbudowaniu mapy. Do zrobienia: ekran wejścia zasłaniający ten moment.
2. **Podłoga bywa niemal czarna** w foyer i pokoju startowym. Światło wymaga strojenia na ekranie.
3. **Gracz może znaleźć Kadrowego zbyt szybko**: w jednym teście dotarł do sceny i wyciął gracza krótko po pierwszych błędnych próbach. Balans jest niesprawdzony.
4. **Noclip** omija ukrytą ścianę (ruch jest po stronie klienta). Nagrody i tak wymagają pełnego przebiegu po stronie serwera.
5. **Znajomi na innym serwerze huba** nie zobaczą drużyny. Globalna lista jest poza slice.
6. ~~**Powrót po rozłączeniu** do zakończonego serwera utworzy nowy, pusty przebieg.~~ Obsłużone w dziesiątym przebiegu (odesłanie do huba), nieprzetestowane.
7. **Dźwięki są tymczasowe i niespójne**, np. sygnał krótkofalówki zastępuje klik kamery. Brak: Hum, Projector, Wrong, Music, kroki na wykładzinie.
8. **Tekst po stronie gracza nie przeszedł korekty.** EN i PL napisałem sam.
9. **Sekwencje specjalne z GDD nie są zrobione**: dwa momenty „każdy widzi inny numer”, EQ dla dźwięków za ścianą, plakaty i dokument „Ławka”.
10. Komunikat `rbxassetid://203785492 ... Asset type does not match` pojawia się przy starcie. To nie jest ID z tego projektu, a źródła nie ustaliłem. Nie wpływa na grę.

## Następne kroki

1. **Zagraj sam od początku do końca**, a potem daj zagrać 2–3 osobom bez instrukcji. To główny test koncepcji z `01_KONCEPCJE.md`.
2. Opublikuj oba miejsca według README i przetestuj teleport, zapis oraz 2–4 graczy.
3. Telefon: FPS, przyciski, czytelność.
4. Dopiero potem: strojenie światła, art pass przeciwnika i widowni, własny zestaw dźwięków.

## Przebieg treści (po pierwszym statusie)

Dodane: ekran wejścia, podpowiedzi sterowania krok po kroku, tempo radia, anomalie w tle osobne dla każdego gracza (`Core/Omens`, `OmenDirector`), wystrój misji, film z widownią, a w lobby tablica personelu ze zdjęciem gracza, szatnia personelu, ekspres, telewizor i krzesła po misji.

Widziałem w Studio: ekran wejścia, pierwszą podpowiedź, wystrój foyer i sali, wystrój hali lobby, krzesła po misji, telewizor i tablicę personelu z awatarem.

Anomalie: test na czasie przyspieszonym 10× uruchomił kroki, odwrócone krzesło, gasnący panel, dzwonek i odwrócony rząd. Krzesło w przejściu, pukanie i postać w korytarzu czekały na warunek (gracz stał nieruchomo) i się nie odpaliły. Pierwsza wersja blokowała całą kolejkę na jednej anomalii; to naprawione.

Niesprawdzone: szafka z nazwą gracza, film z widownią, kolejne kwestie radia poza pierwszą, wygląd i brzmienie anomalii. Działają tylko logi, nikt ich nie oglądał ani nie słyszał. Podpowiedzi po pierwszej też nie oglądałem.

Sesja bez ruchu zakończyła się sama, co potwierdza drogę do porażki, ale nie zmierzyłem długości karencji.

**Atrapa, świadomie:** szatnia personelu jest tylko pomieszczeniem. Personalizacja jeszcze nie działa, a ekspres daje tylko dźwięk.

## Trzeci przebieg: pełna misja

Przebieg misji po zmianach: nagranie i taśma, siedzenia, płaszcze, zanik prądu, kod z kartek w piwnicy, magnetofon w gabinecie, szpule w kolejności, projektor, ukryte drzwi, rejestr, kulminacja, dzwonek, finałowa taśma, raport.

Sprawdzone w Studio, solo, sterowane skryptem:

| Test | Wynik |
|---|---|
| Cały łańcuch faz od Protocol do Done | OK |
| Kod: solo dostaje 3 cyfry, zły kod odrzucony, dobry przywraca prąd | OK |
| Klawiatura kodu prawdziwymi kliknięciami myszy | OK |
| Kartki widać tylko przez wizjer | OK |
| Magnetofon: seans i kolejność szpul na ekranie | OK |
| Zła szpula zeruje projektor i liczy się jako błąd | OK |
| Kadrowy skacze po węzłach po zaniku prądu, obraz z szyją w suficie | OK |
| Ostrzeżenie „TRWA REJESTRACJA” i zakłócenia w wizjerze | OK |
| Widownia wstaje rzędami od tyłu | OK |
| Raport z wyróżnieniami po sukcesie | OK |
| Szafka: zablokowana ramka odrzucona, dostępna zapisana, śmieciowe dane bez skutku | OK |
| Tablica personelu z awatarem, krzesła po misji | OK |

Niesprawdzone:

- Ostateczna jasność zaciemnienia bez kamery. Lampy strojone na oko, tuż przed końcowym buildem.
- Działanie cyfr u 2–4 graczy. Podział ma tylko test logiki.
- Reakcja na Kadrowego pod koniec rejestracji w grze ręcznej, balans tempa, czas przejścia.
- Migawka autobusu na finałowej taśmie.
- Nadal całe: multiplayer, telefon, kontroler, teleport, DataStore, brzmienie dźwięków.

Do testów w Studio służą atrybuty Workspace: `DevPauseRegistrar`, `DevOmenSpeed`, `DevCompletions`, `DevMissionDone`. Działają tylko w Studio. Kod, kolejność szpul i rozwiązanie serwer wypisuje w Output.

**Atrapy, świadomie:** ekspres daje tylko dźwięk, pozostałe szafki nie mają funkcji. Oprawa to bryły z materiałów wbudowanych.

## Czwarty przebieg: sobowtór, dźwięk, scenografia

Dodane: sobowtór (klon awatara gracza idący jego trasą sprzed około 30 s, znika po dłuższym spojrzeniu), losowe dźwięki pomieszczeń tłumione przez ściany, dźwięk projektora, dźwięk wstawania rzędów, zróżnicowana widownia (ubrania i włosy), ramy i skrzydła drzwi, okna z zimnym światłem i kamienna podłoga w foyer, kinkiety, a w lobby pudła, wózek z taśmami, drabina i chodnik.

Sprawdzone: Dubel 3 startuje z odwróconymi rzędami i właściwą odprawą, wizjer na żywo ukrywa widownię, Kadrowy czeka w tylnej części sali. Sobowtór odpalił się dwa razy na czasie przyspieszonym 8×, a klon wygląda poprawnie, co obejrzałem osobno w lobby. Nowy wystrój lobby obejrzałem na zrzucie.

Zauważone: klon stoi nieruchomo w pozie bezczynnej i sunie po trasie. Jest to celowe, ale wymaga oceny na żywo.

Niesprawdzone: sobowtór oglądany w ruchu w misji, Dubel 2 w grze, nowe okna i kinkiety na zrzucie (zrzut przekroczył czas), brzmienie nowych dźwięków. Ramy drzwi i okna nie zostały obejrzane.

## Piąty przebieg: grafika i modele

**Znaleziony błąd krytyczny, naprawiony:** drzwi z foyer do sali były zamurowane. Otwór okna kabiny nakładał się w `Build.wallX` na otwór drzwi i kod wypełniał całą szerokość do wysokości okna. Wszystkie wcześniejsze przebiegi przenosiły postać skryptem, więc tego nie wykryły. Żaden gracz nie wszedłby do sali. Podział ścian jest teraz w czystym module `Core/WallSpans` z testem.

**Wniosek do testów:** teleport testowy nie dowodzi dostępności. Trasy trzeba przechodzić Humanoidem.

Dodane: materiały powierzchni, modele rekwizytów i postaci, bojler, lampa, ekspres, pudła, terminal na biurku, wstępne ładowanie modeli przy starcie klienta i ciemny kolor zapasowy na czas ładowania. Pełna lista jest w `06_ASSETS.md`.

Naprawione przy okazji: błędne rozmiary siatek krzesła i dwóch modeli widowni (krzesła wisiały w powietrzu, postacie wyglądały jak dzieci), położenie włosów i pasków na oczach, białe ciała widowni przy pierwszym podniesieniu kamery, białe tyły ud brązowego garnituru.

| Test w Studio (solo) | Wynik |
|---|---|
| Humanoid: start → sala przez drzwi foyer, końcowa wersja | Doszedł w 7 s |
| Humanoid: sala → korytarz → podest → rampa → piwnica | Doszedł (przed dodaniem modeli bojlera i lampy) |
| Humanoid: wejście z sali do biura | Przeszedł (start skryptem tuż przed drzwiami) |
| PathfindingService: sala, scena, szatnia, kabina, korytarz, podest | Ścieżka istnieje |
| PathfindingService: piwnica, biuro, archiwum | `NoPath` dla wybranych punktów docelowych |
| Zrzuty: sala gołym okiem i przez wizjer, foyer, szatnia, kabina, archiwum, biuro, piwnica, Kadrowy, lobby | Obejrzane |
| Bramki: rojo, lune (46 testów), selene, stylua | Zielone |

Pomiary w Studio na tym komputerze, w Play z wizjerem:

| Miejsce | Części | Siatki | FPS | Pamięć |
|---|---|---|---|---|
| Misja | 1637 | 482 | 53–65 | około 2,7 GB |
| Lobby | 321 | 184 | 65 | około 2,6 GB |

Pamięć to wartość całego Studio, nie gry. Liczby nie mówią nic o telefonie.

Niesprawdzone:
- wejście do archiwum pieszo przez ukryte drzwi po tej zmianie,
- przejście intra w lobby po tej zmianie i dojście pieszo do terminala,
- pełny łańcuch misji na końcowej wersji; ostatni pełny przebieg był przed zmianą grafiki i był prowadzony skryptami, z teleportami,
- gra człowieka, 2–4 graczy, telefon, kontroler, teleport, DataStore, brzmienie dźwięków.

Znane problemy:
- konsola Studio pokazuje wiele komunikatów „Asset content representation is being generated” dla świeżo wygenerowanych assetów; modele mimo to się wyświetliły, ale świeży asset może przez chwilę nie być widoczny,
- pochodzenie komunikatu o `rbxassetid://203785492` (zły typ assetu) nadal jest nieznane,
- kartony w lobby są różowawe, a półki mają miejscami trójkątne artefakty tekstury,
- lada w lobby i czerwone lampy awaryjne to nadal bryły,
- jasność piwnicy i zaciemnionych rogów archiwum trzeba ocenić na żywo.

## Szósty przebieg: pełna misja pieszo

Stan na 2026-11-07. Trzy przejścia misji w Studio, solo, na końcowej grafice. Postać szła wyłącznie przez `Humanoid:MoveTo`, bez teleportów. Prompty i taśmy obsługiwały prawdziwe klawisze (E, Q, R, T), a klawiaturę kodu i przyciski X prawdziwe kliknięcia. Skrypt testowy ustawiał tylko kierunek kamery i znał rozwiązanie zagadki z Output, więc to nadal **nie jest gra człowieka**.

**Naprawione błędy:**

1. **Dokumentów w misji nie dało się zamknąć myszą.** `LockFirstPerson` trzyma kursor na środku ekranu, a przycisk X jako jedyny nie miał `Modal`. Okno zostawało na środku widoku do następnej taśmy. X ma teraz `Modal`, a na kontrolerze dokument zamyka B, które poza tym zostaje komunikatem radiowym. Dotyczyło to każdego dokumentu, także rejestru.
2. **Wskazówka z magnetofonu nachodziła na napis radia** i kolejność szpul była prawie nieczytelna. Napis jest teraz u góry obrazu, na własnym tle.
3. **Napis „Możesz wrócić przy znaczniku” ginął na plakatach.** Dostał obrys.

| Test (solo, Studio) | Wynik |
|---|---|
| Łańcuch Protocol → Done z wstrzymanym Kadrowym | OK, bez blokad na trasie |
| Łańcuch Protocol → Done z aktywnym Kadrowym, jedno odtworzenie | OK, jedno wycięcie po drodze |
| Trasy: start → sala → szatnia (wokół lady) → piwnica i z powrotem | OK |
| Trasy: gabinet, kabina przez rampę, kulisy i korytarz z kotarami do piwnicy | OK |
| Ukryte drzwi po obu stronach: bez kamery ściana blokuje, z kamerą przepuszcza | OK |
| Droga z archiwum przez drzwi do dzwonka po przeczytaniu rejestru | OK |
| Karty kodu ze sceny przez wizjer, poprawne cyfry | OK |
| Film pokazuje drzwi po właściwej stronie (sprawdzone dla strony +1) | OK |
| Wycięcie, 30 s, powrót pieszo na znacznik w foyer | OK, dwa razy |
| Porażka: wszyscy poza kadrem, koniec karencji i raport | OK, czasu karencji nie mierzyłem dokładnie |
| Finałowa taśma z datą za tydzień i „192 + 1”, raport po sukcesie | OK |
| Migawka autobusu | Dalej nieobejrzana |
| Lobby: regulamin, kamera, dwa uniesienia, drzwi, droga pieszo do terminala, panel terminala | OK |
| Błędy skryptów w logach misji (trzeci przebieg) i lobby | Brak |
| Bramki: rojo, lune (46 testów), selene, stylua | Zielone |

Zamykanie dokumentu przyciskiem B sprawdziłem tylko symulowanym klawiszem, bez fizycznego kontrolera.

Do obserwacji:

- **Licznik taśm:** w pierwszym przebiegu po jednym nagraniu serwer zaliczył dwie taśmy (zostało 1 zamiast 2). Przy tej samej sekwencji klawiszy w dwóch kolejnych przebiegach licznik był poprawny. Przyczyny nie ustaliłem. W tamtym przebiegu skrypt testowy ładował też moduł `LensView`, ale związku nie potwierdziłem.
- **Numerek z krzesła:** w drugim przebiegu E na właściwym krześle nie dało numerka. Kadrowy wyciął gracza mniej więcej w tej samej chwili, a odrzucenie po wycięciu jest zgodne z kodem. Czasu nie zmierzyłem, więc to najbardziej prawdopodobne wyjaśnienie, a nie pewność. W trzecim przebiegu wszystkie krzesła zaliczały się od razu.
- **Balans:** testowy spacer nie reaguje na Kadrowego. Wycięcia po 2–3 minutach nie mówią więc, jak trudna jest gra dla człowieka, który może go sfilmować w ciągu 1,5 s.

Bez zmian niesprawdzone: gra człowieka, czas przejścia, 2–4 graczy, telefon, fizyczny kontroler, teleport, DataStore, brzmienie dźwięków.

## Siódmy przebieg: pakiet przed testem właściciela

Stan na 2026-11-07. Solo w Studio. Pełnego łańcucha misji nie powtarzałem po tych zmianach. Sprawdziłem pieszo trasy przez zmienione progi, a resztę osobno, częściowo przez ręczne wysłanie zdarzeń `EndMission` i `SessionState`.

**Język:** angielski jest teraz językiem podstawowym, także dla kont z językiem polskim. Szyldy w świecie są po angielsku. Polskie tłumaczenie zostaje w `Strings.luau`, wyłączone flagą `POLISH_TRANSLATION`.

**Migotanie przy drzwiach (zgłoszone przez właściciela):** to z-fighting, czyli powierzchnie w tej samej płaszczyźnie. Skan wszystkich prostopadłościanów znalazł przyczyny:

- ramy drzwi misji leżały w płaszczyźnie cięcia ściany; teraz wchodzą 0,15 w otwór i je przykrywają,
- w lobby `LockerWestLow` nachodziła na `HallEast`, a sufity korytarza i ukrytego pokoju pokrywały się z nadprożami,
- progi drzwi przy kulisach i ukrytych drzwiach pokrywały się z podłogą; otwory sięgają teraz ziemi, a podłogi je wypełniają,
- sufit foyer pokrywał się z dołem ścian kabiny i rampy,
- chodniki, dywan i znacznik podniesione z 0,05–0,06 do 0,1.

Ponowny skan: w lobby brak konfliktów, w misji zostały tylko styki niewidoczne dla gracza. Skan nie obejmuje siatek (`MeshPart`), a samo migotanie w ruchu musi potwierdzić właściciel, bo zrzut jest nieruchomy.

Przy okazji: tabliczki rzędów i kinkiet wisiały w otworach drzwi. Tabliczek przy drzwiach już nie ma (litera została na drugiej ścianie), a kinkiet wisi obok.

**Dźwięk:** dobrane `Hum`, `Wrong`, `Music`, `LensUp`, `RecStart`, `Radio`, `Projector`, `TapeMotor`. Wszystkie ładują się w Studio i mają zmierzoną długość. **Nikt ich nie słyszał**: wybór opiera się na nazwach i długościach. Podłączone: klik przy błędnej odpowiedzi, muzyka w kulminacji i na finałowej taśmie, automatyczne tłumienie dźwięków za ścianą w `playAt`. Terminal i ekspres mają własny klik zamiast szumu radia.

**Autobus na końcu:** w świecie renderował się jako czerń z trzema białymi plamami, bo silnik nie zdążał oświetlić nowego miejsca. Jest teraz w `ViewportFrame` z własnym światłem i obejrzany na zrzucie: rzędy krzeseł, lampy, wysoka postać w głębi.

**Taśmy:** nagranie krótsze niż 1 s nie zużywa taśmy (sprawdzone: R-R zostawia licznik na 3). Przyczyny jednorazowego podwójnego liczenia nie ustaliłem. W lobby zaobserwowałem coś, co wygląda na podwójne wykonanie wywołania narzędzia testowego, ale związku nie potwierdziłem.

**Sobowtór:** naprawione przyspieszanie po ok. 90 s gry oraz czas patrzenia zależny od FPS. Pozycje pokazują przejście trasy i zniknięcie po ok. 13 s. Wyglądu w ruchu w misji nie udało się złapać na zrzucie.

| Test (solo, Studio) | Wynik |
|---|---|
| Dubel 2: odwrócony co czwarty rząd, Kadrowy aktywny od startu | OK |
| Szafka: otwarcie, zmiana ramki na Amber, zablokowana ramka bez skutku, zamknięcie | OK |
| Klik przy błędnym krześle, muzyka w sztucznie wywołanej fazie Climax i jej wyłączenie | OK |
| Tłumienie: dźwięk za ścianą z EQ, w linii wzroku bez | OK |
| Humanoid przez drzwi kulis i oba otwory ukrytych drzwi (ściana wyłączona skryptem), wysokość stabilna | OK |
| Błędy skryptów w logach lobby | Brak |
| Bramki: rojo, lune (46 testów), selene, stylua | Zielone |

Uwaga do `DevPauseRegistrar`: działa tylko na budzenie, więc w Dublu 2 Kadrowy i tak poluje.

Dodane później tego samego dnia:

- **Ramy drzwi w lobby:** cztery wejścia. Przejście pieszo przez wszystkie i skan bez widocznych konfliktów. Obejrzane na zrzucie: wejście do pokoju taśm.
- **Kulminacja:** po przeczytaniu rejestru zegar w foyer przeskakuje z 18:04 na 18:05, a EXIT zmienia się w NO EXIT. W Studio ta sama pętla uruchomiona ręcznie trafiła w oba napisy, a zegar obejrzałem na zrzucie. Nie sprawdziłem tego przez prawdziwy odczyt rejestru ani wyglądu NO EXIT na tablicy.

## Ósmy przebieg: playtest kontrolny

Stan na 2026-11-07. Solo w Studio, na kodzie z niezacommitowanymi poprawkami scenografii i finałowej taśmy. Postać szła przez `Humanoid:MoveTo`, prompty i taśmy obsługiwały prawdziwe klawisze, klawiaturę kodu i X dokumentu prawdziwe kliknięcia. Skrypt ustawiał kamerę i znał rozwiązanie z Output, więc to nadal **nie jest gra człowieka**.

| Test (solo, Studio) | Wynik |
|---|---|
| Bramki: rojo, lune (47 testów), selene, stylua | Zielone |
| Pełny łańcuch Protocol → Done, Kadrowy wstrzymany | OK |
| Pełny łańcuch Protocol → Done, Kadrowy aktywny, wizjer kierowany na niego z bliska | OK, bez wycięcia |
| Nagranie i odtworzenie, licznik taśm po jednym nagraniu | OK, zostały 2 |
| Karta kodu przez wizjer (2/3) zgodna z kodem z Output | OK |
| Rejestr przez prawdziwy odczyt: zegar 18:05 i NO EXIT | OK |
| Finałowa taśma: data za tydzień, „192 + 1”, awatar przy pustym krześle w rzędzie C | OK, obejrzane na zrzucie |
| Raport po sukcesie z wyróżnieniami | OK |
| Lobby: drabina oparta o regał, kartony bez różowej tekstury | OK, obejrzane na zrzucie |
| Błędy skryptów w logach misji (oba przebiegi) i lobby | Brak |

Znalezione problemy:

1. **Napis „Press again to stop” chowa się pod podpowiedzią** podczas odtwarzania taśmy. Oba siedzą przy dolnej krawędzi (0,95 i 0,965 wysokości) i nachodzą na siebie.
2. **Kulminacja nie przyspiesza Kadrowego od razu.** `setClimax` nie skraca bieżącego odliczania, więc pierwszy skok po przeczytaniu rejestru przychodzi w starym tempie (solo ok. 25 s). W tym przebiegu od rejestru do dzwonka minęło ok. 20 s i Kadrowy ani razu nie skoczył szybciej.
3. **„Tags: 30, 38, 5” zostaje w HUD do końca misji**, także po zdjęciu wszystkich szpul.
4. **Puszki A, B, C zostają na stole po załadowaniu** do projektora. Gracz nie widzi, które już włożył.
5. **NO EXIT jest mały** i ze sceny ledwo widać, że napis się zmienił.
6. Kotary przy ekranie są prawie czarne, a okienko kasy w foyer to jednolicie czarny prostokąt.

Niesprawdzone w tym przebiegu: magnetofon w gabinecie (kolejność szpul wzięta z Output), wycięcie i powrót, porażka, migawka autobusu (zrzut trafił już w raport). Czas 10:25 z raportu obejmuje pracę skryptu testowego i nie mówi nic o czasie przejścia człowieka.

**Poprawki po przebiegu (punkty 1–4)** i trzeci przebieg z aktywnym Kadrowym na tym kodzie:

| Poprawka | Plik | Sprawdzone w Studio |
|---|---|---|
| „Press again to stop” podniesiony na 0,9 wysokości | `Playback.luau` | Podczas odtwarzania napis zajmuje y 583–607, podpowiedź y 627–655 (ekran 739 px) |
| Wiersz „Tags” tylko w fazie Protocol | `Hud.luau` | Widoczny przy płaszczach, znika po zdjęciu ostatniej szpuli |
| Załadowana puszka znika ze stołu, zła szpula przywraca wszystkie | `Puzzles.luau` | Zła B: wszystkie trzy widoczne; potem A i C znikają, zostaje B (zrzut) |
| `Registrar.hasten` skraca bieżące odliczanie przy kulminacji | `Core/Registrar.luau`, `RegistrarAi.luau`, test w `Core.spec.luau` | Rejestr w 265,3 s, pierwszy skok w 276,6 s (11,3 s; wcześniej do ok. 25 s) |

Bramki zielone, 48 testów. Kod trafił do otwartego Studio przez łatki `Source`, nie przez ponowne otwarcie buildu.

W tym przebiegu Kadrowy w kulminacji wskoczył na scenę i wyciął gracza stojącego przy dzwonku, bo skrypt przestał go śledzić wizjerem. Węzeł `stage` jest ok. 10 jednostek od dzwonka, czyli w promieniu kontaktu. Powrót pieszo na znacznik w foyer zadziałał („is back in frame”), a drugie podejście do dzwonka zakończyło misję. Finałowa taśma pokazała wysoką postać w drzwiach. Błędów skryptów brak.

Nowa uwaga: płaszcze wiszą co 2,4 jednostki, a E łapie najbliższy prompt, nie ten na środku ekranu. Z odległości kilku kroków skrypt trafił w hak 24 zamiast 33. Człowiek może mieć ten sam problem.

## Dziewiąty przebieg: oprawa, lobby, muzyka, UI

Stan na 2026-11-07, po uwadze właściciela, że całość wygląda nudno, lobby nie jest intuicyjne i brakuje muzyki. Sprawdzone w Studio na świeżych kopiach buildu (`build/HubCheck*.rbxl`, `build/MissionCheck.rbxl`). Bramki zielone, 48 testów.

| Zmiana | Pliki | Sprawdzone |
|---|---|---|
| Płaszcze: E działa tylko na płaszcz najbliżej środka widoku (lokalnie zerowany `MaxActivationDistance` pozostałych) | `Controllers/CoatAim.luau` | Patrząc na 15, 24, 33 i 5, aktywny jest zawsze ten jeden |
| NO EXIT w kulminacji: szeroki czerwony neon z poświatą, mruga przy zapaleniu | `MissionWorld.sealExit` | Na zrzucie ze sceny czytelny. Wywołany przez `sealExit` na prawdziwym znaku, nie przez odczyt rejestru |
| Lobby: lada recepcji zjechała z osi, chodnik prowadzi prosto do terminala | `HubWorld`, `HubDressing` | Przejście pieszo z korytarza do terminala bez omijania |
| Terminal: ciepły reflektor, świecący ekran, podświetlany szyld EXPEDITIONS na linkach, kurz w świetle | `HubWorld`, `HubDressing` | Zrzut z wejścia do hali |
| Po intrze cel „Sign up for an expedition at the terminal, end of the hall.”, znika po otwarciu terminala | `Intro.luau`, `Strings` | Tak |
| Kamera na biurku złożona z części (korpus, obiektyw, wizjer, dioda REC), lampa biurowa jako model | `HubWorld`, `HubDressing`, `Intro` | Zrzut; po zabraniu wszystkie części znikają |
| Muzyka: w lobby od otwarcia drzwi, w misji niski dron od Protocol do kulminacji. Obie w grupie ambientu, więc cichną przed skokiem Kadrowego | `AudioDirector.setBed`, `Sounds`, `Silence`, `Intro` | Grają, załadowane, 171 s i 238 s. **Nikt ich nie słyszał** |
| Własne prompty: klawisz w ramce, akcja, obiekt na zielono, czerwony pasek przytrzymania, na dotyku stuknięcie | `PromptUi.luau`, `PromptText` | Wygląd przez kopię karty w `ScreenGui` (zrzut nie rysuje billboardów); na dotyku nie sprawdzone |
| Karta celu w misji, podpowiedzi i radio na ciemnym tle | `Hud`, `Hints`, `Ui.caption` | Zrzuty |
| Terminal: wypełnione przyciski główne, linia pod tytułem, poświata, instrukcja | `Terminal.luau`, `Ui.primary` | Zrzut panelu lobby; widok drużyny niesprawdzony |
| Światło `Future`, mocniejszy kontrast i bloom, niższy ambient, winieta | `*.project.json`, `Config/Lighting`, `Vignette.luau` | Zrzuty obu miejsc |

Wybór muzyki: z Creator Store, po wyszukaniu i zmierzeniu długości w Studio (`work/sfx`, poza repozytorium). Lobby: „Dark Ambient Piano”, misja: „Existential Dread (Deep Dark Ambient Drone)”. Zapasowa dla lobby w komentarzu w `Sounds.luau`.

Niesprawdzone: brzmienie muzyki, wydajność `Future` na telefonie, prompty na dotyku i kontrolerze, NO EXIT przez prawdziwy odczyt rejestru, wygląd terminala w drużynie i na ekranie przygotowania. Okienko kasy w foyer to nadal czarny prostokąt. Dwie ostatnie drobne poprawki (obrys napisu radia gaśnie razem z tekstem, odstęp instrukcji w terminalu) są tylko w kodzie, bez zrzutu.

## Dziesiąty przebieg: powrót do zakończonej ekspedycji, kasa, kotary

Stan na 2026-11-08. Zmiany tylko w kodzie, **bez uruchomienia w Studio** (w tej sesji nie było dostępu do Studio). Bramki zielone: rojo (oba miejsca), lune (48 testów), selene, stylua. `scripts/check.py` wymaga Pythona, którego na tym komputerze nie ma w PATH, więc bramki uruchomiłem tymi samymi poleceniami ręcznie.

| Zmiana | Pliki | Sprawdzone |
|---|---|---|
| Znany problem 6: hub dodaje do teleportu powrotu `rejoin = true`. Misja, która dostaje taki powrót bez wygenerowanej zagadki (stary serwer już się zamknął), albo gracza po zakończeniu misji, pokazuje „This expedition has already ended” i po 3 s odsyła go do huba. Taki gracz nie liczy się do drużyny ani do startu przebiegu | `Teleports.luau`, `Session.luau`, `Strings.luau` | Tylko budowa i lint. Wymaga opublikowanej gry |
| Okienko kasy w foyer: ciepło oświetlone wnętrze, lampka, kartka CLOSED, jaśniejsza szyba zamiast czarnego prostokąta | `MissionDressing.luau` | Bez zrzutu |
| Kotary przy ekranie i lambrekin jaśniejsze (116, 38, 40 zamiast 70, 28, 30) | `MissionDressing.luau` | Bez zrzutu |

Do sprawdzenia w Studio: wygląd kasy i kotar oraz brak migotania (kartka CLOSED i lampka leżą przed tylną płytą, szyba przed nimi). Do sprawdzenia po publikacji: powrót do żywej ekspedycji nadal działa, a powrót do zamkniętej odsyła do huba.

## Jedenasty przebieg: lobby przyjemne i orientacyjne

Stan na 2026-11-08, po uwadze właściciela, że lobby nie jest przyjemne ani orientacyjne. Zmiany tylko w kodzie, **bez uruchomienia w Studio** (sesja bez dostępu do Studio). Bramki zielone: rojo (oba miejsca), lune (48 testów), selene, stylua.

**Światło.** Lobby ma teraz własny preset `Hub` w `Config/Lighting.luau` (`LightingApply.apply("Hub")`): cieplejszy ambient, mniejsza mgła, lekka saturacja i cieplejszy tint. Misja dalej używa presetu bazowego, więc jej mrok się nie zmienia. W hali zamiast jednego rzędu paneli jest siatka 3×3 ciepłej bieli; alejki przy ścianach doświetlają kinkiety na boazerii (3 po zachodniej, 2 po wschodniej stronie), nad ladą recepcji wiszą dwie lampy, a pokój startowy i szatnia dostały cieplejsze panele.

**Orientacja.** Przy wejściu do hali, na wprost drzwi z korytarza, wiszą trzy podświetlone tablice kierunkowe: „EXPEDITIONS ^", „TAPE ROOM > / PERSONNEL >", „< RECORDS" (z = 16, czyli w wolnym pasie między regałami, które kończą się na z = 14, a ścianą południową). Wzdłuż chodnika do terminala biegną niskie zielone światełka prowadzące co 8 jednostek. Nad drzwiami do korytarza, od strony hali, wisi zegar 18:04. Korytarz dostał boazerię, dwa kinkiety i tablicę „REGISTRY HALL AHEAD".

**Przyjemność.** Kącik oczekiwania między regałem zachodnim a chodnikiem: dywan, dwa krzesła przed telewizorem, stolik z kubkiem i lampa podłogowa. Trzy rośliny doniczkowe: przy ekspresie, przy wejściu do hali i wyższa przy terminalu.

Współrzędne nowych brył sprawdziłem ręcznie względem regałów (x ±18–22 i ±28–32, z 2..14), wózka, lady i ścian; tablice i kącik przesunąłem po pierwszej wersji, która nachodziła na regały. **Nikt tego nie widział na ekranie.** Do oceny w Studio: czy hala nie zrobiła się za jasna (strach ma zostać w misji), czytelność tablic z progu korytarza, brak migotania przy kinkietach i boazerii, czy rośliny nie wyglądają tandetnie.

## Dwunasty przebieg: zrozumiałość i brak blokad

Stan na 2026-11-09, po prośbie właściciela, żeby gra była zrozumiała i intuicyjna. Zmiany tylko w kodzie, **bez uruchomienia w Studio** (sesja bez dostępu do Studio). Bramki zielone: rojo (oba miejsca), lune (51 testów), selene, stylua.

| Zmiana | Pliki | Sprawdzone |
|---|---|---|
| **Blokada naprawiona:** gracz miał 3 taśmy na całą misję. Po ich zmarnowaniu nie dało się znaleźć brakujących szpul i misja stawała. Na ladzie kasy w foyer stoi teraz pudełko „BLANK TAPES”, które oddaje jedną taśmę graczowi z pustym licznikiem. Po ostatnim nagraniu radio mówi, gdzie jest pudełko, a komunikat „No tape left” też je wskazuje | `Tapes.luau`, `Strings` | Budowa i lint |
| Linia „> …” na karcie celu: konkretny następny krok wyliczony z tego, co gracz wie (własne taśmy, odczytane cyfry, numerki zgłoszone przez drużynę). Logika w czystym module `Core/Guide` | `Core/Guide.luau`, `Notebook.luau`, `Hud.luau` | 3 nowe testy Lune |
| Radio jednorazowo mówi wprost, co zrobić, gdy gracz stoi na jednym kroku dłużej niż jego limit (od 35 s przy dzwonku do 150 s) | `Core/Guide.luau`, `Notebook.luau` | Tylko testy logiki |
| Po każdej taśmie napis: w którym rzędzie ktoś się odwrócił albo że nikt. Podpowiedź „Someone on the tape turned round” pojawia się tylko, gdy taśma kogoś złapała | `Notebook.luau`, `Hints.luau`, `Playback.onStopped` | Budowa |
| Notatnik terenowy (J, L1, przycisk NOTES na dotyku): cel, następny krok, wskazówki (rzędy z taśm, miejsca i numerki, szpule, kod odczytany z kartek, kolejność szpul, strona drzwi), ponowne czytanie dokumentów i rejestru, sterowanie dla aktualnego urządzenia, jasność | `client_common/Journal.luau`, `Notebook.luau`, `CodeCards.onSeen` | Budowa |
| Cyfra kodu trafia do notatnika dopiero, gdy kartka była na ekranie z odległości do 50 jednostek, więc notatnik nie zdradza kodu bez spojrzenia przez wizjer | `CodeCards.luau` | Budowa |
| Jasność: 6 poziomów, przenoszona przez teleport (`TeleportService` teleport settings) | `client_common/Brightness.luau`, oba `Boot.client.luau` | Budowa |
| Lobby: panel pomocy pod J z opisem pomieszczeń, sterowaniem i jasnością | `HelpPanel.luau` | Budowa |
| Terminal: PLAY SOLO tworzy drużynę jednoosobową, ustawia gotowość i od razu odlicza. CREATE EXPEDITION zostaje dla gry ze znajomymi, tekst pomocy opisuje oba wejścia | `Parties.luau`, `Terminal.luau`, `Strings` | Budowa |

Do sprawdzenia w Studio:
- czy pudełko na ladzie (x 21–23,8, z 47,6–48,6, na blacie 3,4) nie nachodzi na nic i czy prompt nie zasłania promptu listy obecności (x 16–17,4),
- czy tag „[J] NOTES” w prawym górnym rogu nie koliduje z przyciskami Roblox i z HUD-em wizjera (chowa się przy podniesionej kamerze),
- czy notatnik zwalnia kursor (przycisk CLOSE ma `Modal`) i czy B zamyka go na kontrolerze,
- czy linia „NEXT” nie robi z karty celu zbyt długiego bloku na telefonie,
- czy podpowiedzi radia nie przychodzą za wcześnie dla człowieka (limity w `Core/Guide.luau`),
- PLAY SOLO w Studio kończy się komunikatem o braku publikacji, tak jak BEGIN; pełny przebieg wymaga opublikowanej gry.

## Trzynasty przebieg: strach, postacie, większa piwnica, UI

Stan na 2026-11-09, po prośbie właściciela o lepsze UI i postacie, większe pomieszczenia, ciekawszą misję i więcej strachu. Zmiany tylko w kodzie, **bez uruchomienia w Studio**. Bramki zielone: rojo (oba miejsca), lune (51 testów), selene, stylua. Nowych modeli 3D nie było jak zrobić bez Studio, więc postacie „ożywają” przez zachowanie, nie przez nowe siatki.

| Zmiana | Pliki |
|---|---|
| **Widownia patrzy:** od zaniku prądu, przez wizjer, kilka postaci w zasięgu 28 jednostek powoli obraca się na krzesłach w stronę kamery i ją śledzi. Ich liczba rośnie z fazą (3 → 14 w kulminacji), a po opuszczeniu kamery wracają na miejsce. Rząd A (kod) i fazy z zagadką taśm są wyłączone, żeby nie mylić z „odwróconą osobą” | `Audience.luau` |
| **Bliskość Kadrowego:** gdy jest obudzony, bicie serca przyspiesza z odległością (62 → 12 jednostek), a brzegi obrazu pulsują na czerwono. Przy każdym jego skoku światła w promieniu 48 jednostek migają. Bicie serca to tymczasowo przyciszony, obniżony `Reach` (`Sounds.Heartbeat`) | `Dread.luau`, `Sounds.luau` |
| **Nowe anomalie:** szept imienia gracza zza pleców (od ok. 230 s), twarz z widowni tuż przed obiektywem na 0,4 s przy podniesionej kamerze (raz, od ok. 340 s), dwusekundowe zaciemnienie całego budynku dla jednego gracza (od ok. 430 s, nie w fazie Power) | `Core/Omens.luau`, `OmenDirector.luau` |
| **Większa piwnica:** za kotłownią, przez drzwi w jej południowej ścianie (x −74…−66), jest magazyn 40 × 38 z czterema rzędami regałów otwartych na zmianę z dwóch stron, czyli jedna długa alejka w kształcie węża (ok. 140 jednostek). Bezpiecznik i kartka stoją na końcu, pod czerwoną lampą awaryjną, która po zaniku prądu jest jedynym światłem. Kadrowy ma tam nowy węzeł `cellar`. Zapasowe krzesła w kotłowni przesunięte pod wschodnią ścianę | `MissionAnnex.luau`, `Core/Layout.luau`, `Strings` |
| **Plansze rozdziałów:** każda faza zaczyna się kinową planszą „PART I–V” z nazwą wpisywaną znak po znaku (pierwsza z miejscem i datą). Czeka, aż skończy się taśma | `Titles.luau`, `Strings` |
| **Notatnik:** sekcja „WHAT WE KNOW” z zasadami odkrywanymi w grze (taśma, seanse, cisza, patrzenie za długo, sięganie, wycięcie z kadru). Tag w rogu robi się czerwony z „+” przy nowym wpisie | `Notebook.luau`, `Journal.luau` |
| **Kontroler:** terminal, archiwum, szafka, klawiatura kodu i okno powrotu zaznaczają pierwszy przycisk dla D-pada, a B je zamyka | `client_common/Panels.luau` i kontrolery paneli |
| **UI:** komunikaty radia mają zielony znacznik RADIO (rich text, nazwy graczy są escapowane). Terminal pokazuje „1-4 players, about 20 min, headphones recommended” | `Hud.luau`, `Terminal.luau`, `Config/Missions` |

Do sprawdzenia w Studio:
- przejście pieszo kotłownia → drzwi → cała alejka magazynu → bezpiecznik, także z latarką po zaniku prądu (alejki 6, przejścia 9,5, przy skrzyniach min. 3,4 jednostki),
- czy obracające się postacie nie wchodzą zbyt mocno w oparcia krzeseł i czy wyglądają strasznie, a nie śmiesznie,
- brzmienie „bicia serca” z bębna i siła czerwonej poświaty (nie może przeszkadzać w czytaniu),
- czy twarz przed obiektywem wypada na wysokości oczu (zakładam głowę ok. 4,4 nad podłogą postaci),
- czy plansze rozdziałów nie nakładają się na odprawę radia na starcie,
- czas misji po wydłużeniu drogi do bezpiecznika.

## Czternasty przebieg: trendy 2026

Stan na 2026-11-09. Zmiany tylko w kodzie, **bez uruchomienia w Studio**. Bramki zielone: rojo (oba miejsca), lune (51 testów), selene, stylua.

**Co pokazało krótkie badanie trendów** (głównie rankingi i poradniki, więc to sygnały, nie twarde dane):
- najwięcej graczy mają co-op survival (99 Nights in the Forest) i proceduralne roguelite (DOORS), wysoko są też The Mimic, Pressure i Forsaken,
- powtarzają się: eksploracja przestrzeni liminalnych, horror oparty na folklorze, tryby zabójca kontra ocalali, kooperacja z czatem głosowym,
- w grach z czatem głosowym potwór coraz częściej „słyszy” graczy (PANICORE, R.E.P.O., Lethal Company), a sam głos jest częścią mechaniki,
- w indie wracają found footage, analog horror i estetyka VHS, czyli to, na czym HEADCOUNT już stoi,
- popularne jest też szukanie anomalii, w stylu Exit 8 czy Observation Duty.

Źródła: [everythingedinburgh.com](https://everythingedinburgh.com/games/gaming/best-roblox-horror-games/), [endsights.com](https://endsights.com/best-horror-roblox-games), [rolearn.dev, studium przypadku](https://rolearn.dev/case-studies/horror-multiplayer-viral-loop), [gaming.net](https://www.gaming.net/best-co-op-horror-games-proximity-voice-chat/), [pcgamer.com](https://pcgamer.com/retro-horror-games-are-preparing-to-go-beyond-the-ps1), [wnhub.io](https://wnhub.io/news/indie/item-52426).

| Zmiana | Pliki |
|---|---|
| **Rejestrowanie anomalii:** krzesło w przejściu, postać w korytarzu, sobowtór, odwrócone krzesło i odwrócony rząd można zarejestrować, trzymając je 0,8 s na środku podniesionej kamery (stożek ok. 15°, do 55 jednostek). Przy pierwszej anomalii radio mówi, że się to robi. Licznik trafia do notatnika, raportu końcowego i do zasad w „WHAT WE KNOW”. Zostaje po stronie klienta, bez nagród, więc nie trzeba go chronić przed oszustwem | `OmenDirector.luau`, `Notebook.luau`, `EndTape.luau`, `Strings` |
| **Kadrowy słyszy głos:** przy włączonym czacie głosowym klient mierzy tylko poziom RMS własnego mikrofonu (`AudioAnalyzer` na `AudioDeviceInput`) i tylko w czasie ciszy przed skokiem. Głośna mowa przez 0,35 s wysyła `VoiceNoise`. Serwer przyjmuje to tylko w oknie ciszy, którą sam ogłosił, nie częściej niż raz na 8 s na gracza, i może wtedy zrobić to samo co seans: przyciągnąć Kadrowego o jeden węzeł. Gracz widzi „Something heard you”, a w notatniku pojawia się zasada „keep quiet”. Bez czatu głosowego nic się nie dzieje | `VoiceListener.luau`, `RegistrarAi.luau`, `Net`, `Config/Game.VoiceCooldown` |
| `VoiceChatService`: `UseAudioApi = Enabled`, `EnableDefaultVoice = true` w `mission.project.json`. Sprawdzone przez wczytanie `build/Mission.rbxl` w Lune | `mission.project.json` |

Do sprawdzenia:
- czat głosowy działa tylko w opublikowanej grze, przy włączonym głosie w ustawieniach doświadczenia i u graczy z weryfikacją wieku. Próg 0,12 RMS jest strzałem i trzeba go dostroić na prawdziwym mikrofonie,
- czy czas 0,8 s i stożek 15° przy rejestrowaniu nie są za trudne dla postaci w korytarzu, która znika po ok. 1,1 s patrzenia,
- kwestionariusz Maturity & Compliance: gra analizuje głośność mikrofonu (nie treść); warto to opisać w opisie gry.
