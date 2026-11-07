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
6. **Powrót po rozłączeniu** do zakończonego serwera utworzy nowy, pusty przebieg. Trzeba to obsłużyć po pierwszych testach.
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
