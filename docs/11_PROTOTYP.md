# 11. Zmiana: jak ją uruchomić i co sprawdzić

Stan na 2026-11-20. Gałąź `prototype-shift`. Etap 0 z `09_GDD_V2.md` §12 (prototyp) i kod Etapu 1 (alfa), razem z windami w lobby i teleportem. Misja 001 jest nietknięta.

## 1. Co jest w grze

### Etap 0 (prototyp)

- **Osobne, trzecie miejsce: Shift** (`shift.project.json` → `build/Shift.rbxl`). Działa samo, bez teleportu.
- **Winda:** stoi w miejscu, a za zamkniętymi drzwiami powstaje kolejne piętro.
  - Tabliczka nad drzwiami pokazuje piętro i liczbę postaci w kabinie.
  - Przyciski na bocznej ścianie, przy drzwiach: **DOWN** (czerwony, niżej) i **UP** (zielony, wyżej). Oba wymagają, żeby cała drużyna była w kabinie.
  - Drzwi zamykają się przez 4 s, ale stoją, gdy Kadrowy jest w pomieszczeniu przed windą, a nikt go nie filmuje.
- **Zjazd:** około 12 s, z jednym losowym zdarzeniem (mrugające światło, kroki na dachu albo wskaźnik pokazujący −13). Na końcu dzwonek.
- **Piętra −1 do −5:** losowo złożone z pomieszczeń, z pętlami. Każde piętro niżej jest ciemniejsze i ma inny kolor. Od −4 meble wiszą pod sufitem.
- **Anomalie widać tylko w kamerze:** zwykła (siedzi), rzadka (stoi bez ruchu), epicka (siedzi i obraca się w stronę obiektywu).
- **Nagrania:** serwer ocenia każde od jednej do pięciu gwiazdek. Drużyna dostaje zapłatę za najlepsze ujęcie każdej anomalii.
- **Norma:** 40 punktów solo, +20 za każdą osobę więcej. Nagrania liczą się do normy dopiero po odjeździe windą z piętra. Mnożniki pięter: ×1, ×1,5, ×2, ×3, ×4.
- **Kadrowy:** te same reguły co w Misji 001, szybszy z każdym piętrem, solo wolniejszy.
- **Wycięcie z kadru:** kolega przywraca cię, filmując cię przez 3 s. Solo raz na zmianę możesz po 30 s sam wrócić do windy. Gdy wszyscy są wycięci i nie ma powrotu, zmiana przepada i Biuro płaci 25% tego, co było już w windzie.
- **Kamera:** bateria, wolniejszy chód z podniesioną kamerą, kasety odnawiają się w windzie.

### Etap 1 (alfa), dodane 2026-11-20

- **Statysta (od −2):** chodzi po piętrze jako kopia awatara kogoś z drużyny (solo: twoja), macha „chodź za mną” i cofa się, gdy za nim idziesz. Po chwili albo w ślepym zaułku odwraca się i idzie na ciebie; dotyk wycina z kadru. W kamerze, na taśmie i po wycięciu widać jego prawdziwą postać: za wysoką, z głową poza kadrem.
  - Jak Kadrowy: **nie rusza się, gdy ktoś go filmuje.**
  - Trzymany w kadrze z bliska (do 20 studs) przez 2 s znika. To najlepiej płatne ujęcie w grze (90 przed mnożnikiem) i wpis „The Extra” w Archiwum.
  - Nikogo nie wycina w windzie. Jeśli nikt go nie sfilmuje, z szansą 50% wsiada z drużyną: tabliczka pokazuje o jedną osobę więcej, a po otwarciu drzwi wysiada z wami na następne piętro. Sfilmowany w kabinie znika i płaci od razu.
  - **Lista drużyny** w prawym górnym rogu pokazuje, gdzie naprawdę jest każdy z was (pomieszczenie, winda albo „cut out of frame”).
- **Taśmy (T):** kamera trzyma trzy ostatnie nagrania z bieżącego piętra. T odtwarza ostatnie: kamera leci nagraną ścieżką w wyglądzie VHS, a ty stoisz bezbronny. Pierwsze odtworzenie drużyny na piętrze jest darmowe, każde kolejne przyciąga Kadrowego o jeden węzeł w stronę oglądającego. Od drugiego oglądania tej samej taśmy Kadrowy stoi w jej kadrze, za każdym razem bliżej.
- **Drzwi z kodem (od −2):** jedno ślepe pomieszczenie na piętrze może być zamknięte stalowymi drzwiami z zamkiem. W środku czeka anomalia rzadka albo epicka. Kod jest na drzwiach, ale widać go **tylko na taśmie**: nagraj drzwi, odtwórz taśmę, przeczytaj kod, wpisz go przy zamku (cyframi albo myszą). Trzy błędy zacinają zamek na 8 s. Kod nie trafia do klienta inaczej niż w odtworzeniu taśmy, która objęła drzwi.
- **Kamera spada z nagraniami:** nagrania należą do kamery, która je nakręciła. Wycięty gubi kamerę w miejscu wycięcia razem z tym, co na niej było. Każdy może ją podnieść (E) i wywieźć windą. Bez kamery nie podniesiesz wizjera, dopóki jej nie podniesiesz albo nie dostaniesz nowej w windzie. Kamera zostawiona na piętrze przepada razem z nim.
- **Bileter (od −3):** krąży po ciemnych piętrach i widzi tylko światło latarki. Zapalona latarka w jego zasięgu i polu widzenia ściąga go; dotyk wycina z kadru. Ciemno możesz przejść obok niego. Latarka (F) jest teraz prawdziwym światłem na serwerze, więc widzą ją też koledzy.
- **Zapis postępów:** Klatki, poziomy ulepszeń, rekord głębokości i Archiwum zapisują się w DataStore `Shift_v1` po każdej wypłacie i zakupie, z blokadą sesji (§11.3 GDD): rekord gracza należy naraz do jednego serwera, a blokada wygasa po 150 s bez odświeżenia. Bez dostępu do API (Studio z wyłączonym API Services) wszystko działa w pamięci, a ekran wypłaty mówi „not saved”.
- **Rekord głębokości:** liczy się tylko powrót windą. Widać go na ekranie wypłaty.
- **Archiwum anomalii:** najlepsze gwiazdki każdego rodzaju (Sitter, Stander, Watcher, The Extra), na ekranie wypłaty z licznikiem.
- **Analityka:** zdarzenia `ShiftDescend`, `ShiftEnd` (wynik, czas, liczba graczy), `ShiftCut` (przyczyna) i `UpgradeBought` przez `AnalyticsService:LogCustomEvent`, w `pcall`, więc błąd analityki nie psuje zmiany.

### Lobby i teleport, dodane 2026-11-20

- **Dwie windy w lobby**, we wschodniej ścianie Hali Rejestrów, na północ od pokoju taśm:
  - **SOLO:** wejdź, przytrzymaj E przy przycisku i zjeżdżasz sam.
  - **EKIPA (CREW):** kto stoi w kabinie, ten jedzie. Winda odjeżdża 30 s po wejściu pierwszej osoby, od razu przy czterech albo po przycisku „Leave now”. Kto wyjdzie z kabiny, wysiada. Gracze z drużyną z terminala nie wsiadają (jadą z drużyną).
  - Tabliczki nad drzwiami: przy SOLO twój najgłębszy powrót, przy EKIPIE liczba osób i odliczanie.
- **Terminal:** zmiana jest pierwszą pozycją katalogu, otwartą dla wszystkich. Drużyna znajomych zakłada ekspedycję „THE SHIFT” jak dotąd i startuje razem, a PLAY SOLO działa też dla zmiany.
- **Teleport:** windy i terminal używają tego samego teleportu na zarezerwowany serwer co misja (cała ekipa ląduje na jednym serwerze, z ponawianiem i powrotem po rozłączeniu). Norma liczy się z liczby graczy obecnych przy pierwszym DOWN, więc spóźnieni z ekipy są w niej uwzględnieni.
- **Powrót:** na ekranie wypłaty „BACK TO THE LOBBY”. Serwer zmiany najpierw zapisuje portfel i zwalnia blokadę, potem teleportuje. Gdy teleport się nie uda, odzyskuje blokadę i gracz zostaje.
- Lobby czyta zapis zmiany tylko do odczytu (bez blokady), żeby pokazać rekord.
- Przegląd tej części znalazł i poprawiono m.in.: możliwą utratę zapisu przy nieudanym teleporcie z niezapisanego portfela, podwójny start z windy SOLO, przyciski wind działające przez ściany, teleport mimo nieudanego zapisu i normę pierwszej zmiany liczoną tylko dla pierwszego gracza ekipy (teraz liczy wszystkich wysłanych z lobby).

- **Tablica rekordów** wysoko na wschodniej ścianie hali, nad obiema windami: dziesięć najgłębszych powrotów wszech czasów. Przy równej głębokości wyżej jest ten, kto zarobił więcej Klatek przez wszystkie zmiany (licznik `earned` w portfelu, którego wydawanie nie zmniejsza). Twój wiersz świeci jaśniej. Serwer zmiany zapisuje wynik po każdej zmianie do OrderedDataStore `ShiftRecords_v1` (wynik tylko rośnie), a lobby czyta listę raz na minutę. Bez dostępu do API tablica mówi, że rekordy widać w opublikowanej grze.
- **Rekordy tygodniowe:** obok, bliżej drzwi pokoju taśm, druga tablica z tym samym rankingiem tylko z bieżącego tygodnia. Tydzień zaczyna się w poniedziałek o 00:00 UTC, a nagłówek odlicza czas do resetu. Każdy tydzień ma osobny OrderedDataStore (`ShiftRecords_w<numer tygodnia>`), więc nowy tydzień zaczyna się od pustej tablicy bez żadnego czyszczenia. Portfel trzyma głębokość i Klatki z bieżącego tygodnia (`week`, `weekDeepest`, `weekEarned`) i zeruje je, gdy zaczyna się nowy.

**Do zrobienia przez właściciela:** opublikować `build/Shift.rbxl` jako trzecie miejsce i wpisać jego ID do `MISSIONS.SHIFT` w `src/shared/Config/Places.luau` (README, „Publikacja”). Do tego czasu windy i terminal mówią, że teleport wymaga opublikowanej gry, a w Studio teleport nie działa wcale.

- **Nagrody za miejsce w tygodniu:** pierwsza dziesiątka zakończonego tygodnia dostaje Klatki: 500 za 1. miejsce, 300 za 2., 200 za 3. i po 100 za miejsca 4–10, a do tego wyróżnienie (1st, 2nd, 3rd, Top 10) zliczane w portfelu i pokazywane na ekranie wypłaty. Żaden serwer nie musi działać o północy w poniedziałek: nagrodę odbiera się, gdy zapisany portfel gracza wczyta się na serwerze zmiany. Serwer sprawdza wtedy każdy nierozliczony zakończony tydzień (najwyżej trzy wstecz) i rozlicza go dokładnie raz (`Wallet.rewardedWeek`). Tydzień, którego nie dało się odczytać, zostaje na następny raz. Nagrody to tylko Klatki za grę, zgodnie z §6 GDD.

- **Lista znajomych:** trzecia tablica na tej samej ścianie, nad drzwiami pokoju taśm. Każdy gracz widzi na niej siebie i tych swoich znajomych z Roblox, którzy mają wynik, w tej samej kolejności co tablica wszech czasów, z piętrem z bieżącego tygodnia obok („W -3”). Serwer lobby co 5 minut czyta raz, dla wszystkich graczy, po 500 najlepszych wyników wszech czasów i z tego tygodnia (kilka stron zapytań). Każdemu graczowi dopasowuje znajomych do tej listy i wysyła mu tylko jego wiersze. Tablica jest rysowana lokalnie, więc na jednej tablicy każdy widzi co innego. Znajomy spoza pierwszych 500 nie jest pokazany; przy obecnej liczbie graczy to nikt. Zapytanie o wynik każdego znajomego osobno zjadłoby limit DataStore.

- **Wspólna winda ekipy dla wszystkich serwerów lobby:** gracze w kabinie zajmują miejsca na wspólnym „bilecie” w MemoryStore (`CrewLifts_v2`, logika w `Core/CrewLink`). Bilet to zarezerwowany serwer zmiany, godzina odjazdu i liczba miejsc zajętych przez każdy serwer lobby. Pierwszy gracz w pustej kabinie dołącza do najstarszego biletu z wolnym miejscem (odjeżdżającego za co najmniej 5 s) albo otwiera nowy. Pełny bilet (4 osoby) odjeżdża od razu, a „Leave now” w dowolnym lobby wysyła całą ekipę. W chwili odjazdu każde lobby teleportuje swoich graczy na ten sam zarezerwowany serwer, więc ekipa spotyka się na zmianie. Tabliczka pokazuje liczbę osób w całej ekipie i wspólny czas odjazdu. Bilet zamyka się raz dla wszystkich (pełny, „Leave now” albo pierwsze lobby, które zobaczy, że czas minął), więc lobby z lekko różnymi zegarami odjeżdżają w tej samej sekundzie, a do zamkniętego biletu nikt już nie dosiądzie. Lobby, które ma już miejsca na bilecie, odjeżdża o ostatniej znanej godzinie nawet wtedy, gdy MemoryStore przestanie odpowiadać, więc jedno nieudane zapytanie nie rozdziela ekipy. Dwa lobby, które otworzyły bilety w tej samej chwili, łączą się w starszy. Zamykany serwer lobby oddaje swoje miejsca. Dopiero po trzech nieudanych zapytaniach z rzędu, i tylko gdy lobby nie trzyma biletu, winda działa jak dotąd: tylko z graczami z tego serwera, aż kabina się opróżni. W Studio winda ekipy zawsze działa lokalnie, żeby test nie zajmował miejsc w prawdziwych ekipach.

- **Przewodnik dla nowych prowadzi do wind:** po krokach z kamerą karta celu i znacznik pokazują windy (cel GDD §3: pierwsza zmiana najpóźniej 45 s od wejścia). W kabinie SOLO przewodnik mówi, żeby przytrzymać E przy przycisku; w kabinie EKIPY, że winda odjedzie ze wszystkimi w środku (także z innych lobby) albo od razu po przycisku. Po wyjściu z kabiny wraca do wind. Kto najpierw otworzy terminal, dostaje wskazówkę terminala jak dotąd. Kabinę rozpoznaje po jej podłodze, więc klient nie powiela wymiarów wind.

- **Statyw (G, na kontrolerze D-pad w dół, na telefonie przycisk TRIPOD):** trzecie ulepszenie. Na starcie go nie ma; poziomy dają 12, 20 i 30 s filmowania. Raz na piętro (nowy w windzie) stawiasz go tam, gdzie stoisz, wycelowany tam, gdzie patrzysz. Dopóki ma baterię, wszystko, co ma w kadrze, jest trzymane jak podniesioną kamerą: Kadrowy stoi i nie blokuje drzwi windy, Statysta stoi. Statyw nic nie nagrywa, nie płaci, nikogo nie ratuje i nie ściera Statysty; kupuje czas. Nie świeci, więc Bileter go nie widzi. Gdy bateria się skończy, lampka gaśnie, a właściciel dostaje komunikat. Gracz sam na serwerze płaci za statyw mniej (60 / 140 / 260 zamiast 120 / 220 / 380), zgodnie z §7 i §13 GDD.

- **Obiektyw, noktowizja i latarka:** trzy kolejne ulepszenia. Każde coś kosztuje w grze, więc żadne nie jest po prostu lepsze:
  - **Obiektyw** (x1,25 / x1,5 / x1,8): ujęcia oceniane są tak, jakby kamera stała tyle razy bliżej (więcej gwiazdek z bezpiecznej odległości), ale kadr się zwęża. Węższe pole widzenia ma też serwer: stożek kadrowania kurczy się w tej samej proporcji, więc trudniej utrzymać w kadrze Kadrowego czy kolegę do ratunku. W Misji 001 nic się nie zmienia.
  - **Noktowizja** (poziomy 1–3): przez podniesioną kamerę ciemność jest jaśniejsza (ekspozycja w górę, zielony, wyblakły obraz), a bateria schodzi o 10% szybciej na poziom.
  - **Latarka** (zasięg 55 / 70 / 85 studs zamiast 40): dłuższy, jaśniejszy i szerszy snop, ale Bileter zauważa ją z dalej (16 → 19 / 22 / 25 studs).
  - Ekran wypłaty pokazuje każde ulepszenie w jego jednostkach (s, x zoom, poziom, studs).

- **Taśma zmiany** (§7 GDD): serwer zapamiętuje najlepsze ujęcie zmiany (według tego, ile zapłaciło, z mnożnikiem piętra) i wycina z niego 8 s, które najdłużej trzymały obiekt w kadrze. Na ekranie wypłaty, w panelu obok, taśma gra w pętli: piętro, którego już nie ma, jest odbudowywane z ziarna i głębokości (wspólne moduły `World/FloorBuild` i `World/Figures`, tymi samymi serwer buduje piętro do gry) w ViewportFrame, ze wszystkimi postaciami, które pokazywał wizjer. Kamera leci zapisaną ścieżką, z liniami i opisem jak na kasecie. **SAVE TO ARCHIVE** zachowuje taśmę w zapisanym portfelu (do 5; pełne Archiwum oddaje najsłabszą taśmę za lepszą), a zapisane taśmy można obejrzeć przyciskami w tym samym panelu. Taśma to tylko liczby (ziarno, głębokość, spakowana ścieżka, około 3 KB), więc da się ją odtworzyć gdziekolwiek, także w przyszłości na telewizorze w szafce w lobby. Na wąskim ekranie (telefon) panel taśmy jest pomijany. Ujawnienie Statysty nie trafia na taśmę, bo nie ma nagranej ścieżki kamery.

- **Telewizor w szatni lobby:** stoi na wózku przy wschodniej ścianie szatni, ekranem do wejścia z hali. E otwiera panel z taśmami zmian wszystkich graczy w tym lobby (twoje pierwsze), zgodnie z §5 GDD („każdy może je obejrzeć”). Taśma gra tak samo jak na ekranie wypłaty: piętro odbudowane z ziarna w ViewportFrame (`client_common/TapeView`, wspólny dla zmiany i lobby). Serwer lobby czyta zapis zmiany każdego gracza raz przy wejściu (`HubTapes`, ten sam odczyt daje rekord na tabliczce windy) i wysyła tylko opisy taśm; ścieżkę kamery wysyła dopiero dla taśmy, którą ktoś włączy, a klient trzyma ją do końca wizyty. Taśmy zapisane po wejściu do lobby pojawią się po ponownym wejściu.

- **Zadania dzienne** (§4–5 GDD): trzy dziennie, te same dla wszystkich (łatwe, średnie, trudne, losowane z daty UTC), żeby można było zapytać „zrobiłeś dzisiejsze?”. Każde da się zrobić solo. Pula: nagraj anomalie, rzadkie anomalie, ujęcie na pięć gwiazdek, wróć windą z piętra −2/−3/−5, przywieź ileś nagrań, ukończ zmiany z normą, otwórz drzwi z kodem, obejrzyj taśmę na piętrze, sfilmuj Statystę aż zniknie. Nagrody 40 / 80 / 150 Klatek, wypłacane w chwili wykonania (z komunikatem). Postęp jest w zapisanym portfelu (`Core/Quests`, `Wallet.questEvent`, `ShiftQuests`), a lista z postępem i czasem do nowych zadań stoi w prawym górnym rogu, pod listą drużyny.

- **Biuro Pass** (§4, §6 GDD): sezon 1 „Night Shift” trwa 6 tygodni od poniedziałku 16 listopada 2026 (UTC) i ma 30 poziomów po 100 XP. XP daje każdy punkt nagrań przywieziony windą, +50 za zmianę z normą i 50/100/200 za zadanie dzienne. Każdy osiągnięty poziom wypłaca nagrodę od razu (komunikat „Biuro Pass: …”):
  - **ścieżka darmowa:** 25 Klatek co poziom (50 na 30.), a na poziomach 10, 20 i 30 ramki wizjera, na 15. tytuł,
  - **ścieżka premium** (Game Pass): co drugi poziom ramka wizjera albo tytuł, **bez Klatek**. Klatki kupują ulepszenia, więc Klatki za Robux byłyby przewagą za pieniądze, której §6 GDD zabrania („Nigdy: ulepszenia sprzętu za Robux”). §6 wspomina też „Klatki” w Passie; zinterpretowałem to jako ścieżkę darmową. **Do decyzji właściciela.**
  - Kupiony w trakcie sezonu Pass wypłaca od razu nagrody premium z poziomów osiągniętych wcześniej.
  - Na ekranie wypłaty: postęp, następna nagroda na obu ścieżkach, przycisk odblokowania premium oraz wybór ramki wizjera i tytułu. Tytuł widać przy imieniu na liście drużyny.
  - Ramki z Passa (`Cosmetics.PassFrames`) zakłada się na zmianie, nie w szafce w lobby (ta pokazuje ramki z osiągnięć).
  - **Do zrobienia przez właściciela:** utworzyć Game Pass dla sezonu 1 i wpisać jego ID do `gamePassId` w `src/shared/Config/Pass.luau`. Do tego czasu ścieżka premium pokazuje „coming soon”. Cenę ustawia się w Creator Hub.

- **Pierwsza zmiana** (§3 GDD): gdy wszyscy w windzie są nowi (zapisany portfel bez ani jednej zmiany), zmiana jest prowadzona:
  - tylko piętro −1 („Your first shift is one floor”), norma 25 zamiast 40, Kadrowy śpi 40 s zamiast 25,
  - tuż przed drzwiami windy siedzi zwykła anomalia (`FloorGen.generate(…, guided)`, więc ta postać wraca też na taśmie z tej zmiany),
  - nowy gracz dostaje trzy linie radia w bursztynowym pasku u góry, każdą w swoim momencie: po otwarciu drzwi „podnieś kamerę”, po podniesieniu „nagraj to, bliżej i dłużej znaczy lepiej”, po przebudzeniu Kadrowego „rusza się tylko, gdy nikt go nie filmuje”, a po zrobieniu normy „wracaj do windy i wciśnij UP”,
  - pierwsza wypłata zawiera powitanie Biura, +60 Klatek, więc od razu stać go na pierwsze ulepszenie (bateria kosztuje 60), a ekran wypłaty mu je podsuwa.
  - Gdy w windzie jest choć jeden weteran, zmiana jest zwykła, a nowi i tak dostają linie radia.

- **Rangi** (§5 GDD, „stopień służbowy”) od 1 do 50: to samo doświadczenie co w Biuro Pass (nagrania przywiezione windą, norma, zadania dzienne), ale na stałe, bez resetu sezonu. Ranga 2 przy 100 XP, 10 przy 4500, 50 przy 122 500 (`Core/Rank`).
  - **Głębsze piętra:** ranga 1–2 zjeżdża do −2, ranga 3 do −3, 6 do −4, 10 do −5. Drużyna jedzie tak głęboko, jak pozwala najwyższa ranga w windzie, więc weteran może zabrać nowych znajomych niżej. Przy zablokowanym piętrze winda mówi, od której rangi się otwiera.
  - **Nagrody:** tytuły na rangach 1, 5, 10, 20, 35 i 50, ramki wizjera na 15, 30 i 50. Zakłada się je tak jak te z Passa.
  - Gracze sprzed rang zaczynają z XP równym sumie zarobionych Klatek, więc nikt nie traci pięter, na które już mógł zjechać.
  - Ranga i postęp są na ekranie wypłaty, a przy imionach na liście drużyny jest „[R7]”.
  - **Do decyzji właściciela:** czy Misja 001 (Story Tape) ma być odblokowywana rangą (§10 i pytanie 3 w §13 GDD). Na razie zostaje otwarta dla wszystkich.

**Czego jeszcze nie ma:** taśmy zmiany (klipu z najlepszym momentem), zadań dziennych, dźwięków i grafiki docelowej.

## 2. Jak uruchomić (bez instalowania czegokolwiek)

1. Otwórz https://github.com/Grrim/HEADCOUNT/actions i wybierz najnowszy przebieg „check” na gałęzi **prototype-shift**.
2. Na dole, w **Artifacts**, pobierz **places** i rozpakuj.
3. Otwórz **`Shift.rbxl`** w Roblox Studio i naciśnij **Play**.
4. Pojawiasz się w windzie. Podejdź do czerwonego przycisku na bocznej ścianie przy drzwiach i przytrzymaj **E** (DOWN).

Lokalnie, z narzędziami z `rokit.toml`: `python scripts/check.py`, potem `build/Shift.rbxl`.

**Sterowanie:** Q albo prawy przycisk myszy podnosi kamerę, R nagrywa, **T odtwarza ostatnią taśmę**, **G stawia statyw**, F włącza latarkę, E obsługuje przyciski windy, zamki i podnoszenie kamery. Na kontrolerze: L2, R2, Y, D-pad dół, D-pad góra.

**Test w kilka osób w Studio:** zakładka Test → Clients and Servers, 2–4 graczy.

**Zapis w Studio:** Game Settings → Security → Enable Studio Access to API Services. Bez tego zapis działa tylko w pamięci.

**Atrybut pomocniczy w Workspace:** `DevPauseRegistrar` (boolean) = true usypia Kadrowego, Statystę i Biletera.

## 3. Co sprawdzić (lista dla testu)

**Najpierw, czy w ogóle działa:**
- [ ] Gra startuje bez czerwonych błędów w Output (szukaj `[Loader]`, `[ShiftBank]`).
- [ ] DOWN zamyka drzwi, winda „jedzie”, drzwi otwierają się na piętro −1.
- [ ] Przez kamerę widać postacie w pokojach, a gołym okiem ich nie ma.
- [ ] Nagranie postaci daje gwiazdki i punkty w lewym górnym rogu.
- [ ] Kadrowy budzi się, zatrzymuje w kadrze i wycina po dotyku.
- [ ] UP kończy zmianę i pokazuje ekran wypłaty, na którym da się kliknąć przyciski.
- [ ] NEXT SHIFT zaczyna nową zmianę.

**Etap 1:**
- [ ] T po nagraniu odtwarza taśmę i oddaje sterowanie po końcu albo po drugim T.
- [ ] Na −2 lub głębiej: nagranie drzwi z napisem CODE LOCK, odtworzenie pokazuje trzy cyfry na drzwiach, wpisanie ich otwiera drzwi.
- [ ] Statysta wygląda jak gracz (sprawdź, czy kopia awatara ma ubranie, akcesoria i animację chodu i machania).
- [ ] W kamerze zamiast kopii stoi wysoka postać. Sfilmowany z bliska przez 2 s znika i płaci.
- [ ] Gdy wsiądzie do windy, tabliczka pokazuje o jedną osobę więcej.
- [ ] Wycięty gubi kamerę, kolega ją podnosi i dostaje jej nagrania.
- [ ] Na −3: Bileter idzie na zapaloną latarkę, a obok zgaszonej przechodzi.
- [ ] Po wyjściu i ponownym wejściu (z włączonym API) Klatki i ulepszenia są zachowane.

**Potem, czy jest fajne** (progi z GDD §12):
- [ ] Czy po zmianie testerzy sami chcą zagrać kolejną? (cel: co najmniej 60%)
- [ ] Czy po pierwszej zmianie rozumieją, że Kadrowy rusza się tylko poza kadrem? (cel: co najmniej 70%)
- [ ] Czy przynajmniej w połowie zmian ktoś wybiera „w dół”?
- [ ] Ile trwa zmiana? (cel: 8–15 minut)
- [ ] Czy Statysta rodzi paranoję („to ty?”), czy tylko irytuje?

**Do strojenia** (wszystko w `src/shared/Config/Game.luau`, sekcja `Shift`): czas snu Kadrowego, przyspieszenie na piętro, bateria, wartości anomalii, `Extra` (prędkość, czas wabienia, zasięg ujawnienia), `ExtraBoardChance`, `UsherFromDepth`, `CodeTries`. Norma i mnożniki są w `src/shared/Core/Shift.luau`.

## 4. Czego nie sprawdzono

Kod przechodzi bramki jakości: budowa trzech miejsc, 100 testów logiki (19 nowych: Statysta, sejf z kodem, nagrania na kamerze, zapis z blokadą), selene i stylua. Osobny przegląd kodu pod kątem błędów, które wychodzą dopiero w grze, znalazł m.in. zablokowane drzwi windy przy Kadrowym w progu, brak powrotu do ekranu wypłaty, fałszowanie nagrań i odczyt kodu z ziarna piętra. Wszystkie znalezione problemy są poprawione: nagranie musi teraz iść za prawdziwą pozycją głowy, a kod drzwi losuje serwer osobno. **Ani prototyp, ani alfa nigdy jednak nie działały w Studio.** Najbardziej niepewne:

- kopia awatara Statysty (`Character:Clone()` z animacjami ładowanymi na serwerze),
- czy statyczne animacje R15 z `ShiftExtra` (chód, machanie) się wczytają,
- sygnatura `AnalyticsService:LogCustomEvent` (owinięta w `pcall`, więc najwyżej nic nie zapisze),
- zapis z blokadą na prawdziwym DataStore: po awarii serwera ponowne wejście czeka do około 2,5 min na wygaśnięcie blokady; w tym czasie gra się na świeżym portfelu, a zarobione Klatki dopisują się do zapisu, gdy blokada się zwolni (w Studio blokada jest zawsze przejmowana),
- czytelność kodu na drzwiach w odtworzeniu.

Wklej błędy z Output albo zrzut ekranu, a poprawię.
