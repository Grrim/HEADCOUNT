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

**Do zrobienia przez właściciela:** opublikować `build/Shift.rbxl` jako trzecie miejsce i wpisać jego ID do `MISSIONS.SHIFT` w `src/shared/Config/Places.luau` (README, „Publikacja”). Do tego czasu windy i terminal mówią, że teleport wymaga opublikowanej gry, a w Studio teleport nie działa wcale.

**Czego jeszcze nie ma:** rekordów tygodniowych i list znajomych, wspólnej kolejki windy ekipy między serwerami lobby (ekipa składa się z graczy z tego samego serwera), skrótu do windy w przewodniku dla nowych, statywu i innych ulepszeń poza baterią i kasetami, taśmy zmiany (klipu z najlepszym momentem), zadań dziennych, dźwięków i grafiki docelowej.

## 2. Jak uruchomić (bez instalowania czegokolwiek)

1. Otwórz https://github.com/Grrim/HEADCOUNT/actions i wybierz najnowszy przebieg „check” na gałęzi **prototype-shift**.
2. Na dole, w **Artifacts**, pobierz **places** i rozpakuj.
3. Otwórz **`Shift.rbxl`** w Roblox Studio i naciśnij **Play**.
4. Pojawiasz się w windzie. Podejdź do czerwonego przycisku na bocznej ścianie przy drzwiach i przytrzymaj **E** (DOWN).

Lokalnie, z narzędziami z `rokit.toml`: `python scripts/check.py`, potem `build/Shift.rbxl`.

**Sterowanie:** Q albo prawy przycisk myszy podnosi kamerę, R nagrywa, **T odtwarza ostatnią taśmę**, F włącza latarkę, E obsługuje przyciski windy, zamki i podnoszenie kamery. Na kontrolerze: L2, R2, Y, D-pad góra.

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
