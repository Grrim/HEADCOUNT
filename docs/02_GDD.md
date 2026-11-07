# 02. Game Design Document: HEADCOUNT

Wersja 0.1, 2026-11-06. Oznaczenia: **[VS]** wchodzi do Vertical Slice, **[PÓŹNIEJ]** dopiero po teście VS.

## 1. Filar i obietnica

**Jednym zdaniem:** kooperacyjny horror (1–4 graczy), w którym kamera pokazuje to, czego nie widzi oko, a każde odtworzenie nagrania przybliża to, co na nim jest.

**Trzy filary:**
1. **Dwie prawdy.** Oko i wizjer pokazują różne rzeczy. Żadne z nich nie wystarcza.
2. **Informacja kosztuje.** Odpowiedź jest na taśmie, ale oglądanie jej sprowadza zagrożenie.
3. **Zwyczajność z jednym błędem.** Strach pochodzi z tego, co się nie zgadza, nie z ciemności.

**Odczucie po pierwszej misji:** „Coś tutaj zdecydowanie nie gra. Muszę sprawdzić, co wydarzy się dalej”. Służy temu finałowa taśma, na której siedzą awatary drużyny, opatrzona datą z przyszłości.

**Grupa i etykieta:** 9+, kooperacja ze znajomymi, cel Maturity: **Mild**. Żadnej krwi ani gore. Kluczowe teksty EN i PL.

## 2. Świat i fabuła

### Biuro Ciągłości
Instytucja państwowa z końca lat 70. w nienazwanym kraju Europy Środkowej. Oficjalnie archiwizuje filmową dokumentację zakładów pracy, zebrań i inwestycji. Brak nazwy kraju daje swój klimat: instytucjonalny, „za żelazną kurtyną”, niespotykany na Robloxie, ale zrozumiały globalnie.

**Archiwum 03** to podziemny magazyn na „materiały nieciągłe”: taśmy, które pokazują coś innego przy każdym odtworzeniu. Gracze są nowo zatrudnionymi **asystentami ciągłości**.

### Prawda, odkrywana stopniowo
1. **Warstwa 1 (M001):** Taśmy mają błędy, a miejsca z nich zachowują się dziwnie.
2. **Warstwa 2 (M002–M003):** Dr **Halina Wrona**, inżynierka Biura, w latach 80. naprawiała zniszczone taśmy, dorysowując brakujące klatki. Dorysowane rzeczy zaczęły pojawiać się w miejscach z nagrań. Nagrania nie dokumentują rzeczywistości; rzeczywistość odtwarza nagrania.
3. **Warstwa 3 (M004):** Istnieje **Taśma Zero**, ciągły zapis, którego początku nikt nie zna. Świat jest jej odtworzeniem, a taśma się zużywa. Gdy na taśmie brakuje ludzi, trzeba ich uzupełnić.
4. **Warstwa 4 (M005):** Samo Archiwum 03, w tym lobby, to scenografia z taśmy. Akta graczy mają daty sprzed ich narodzin.

### Antagonista: Kadrowy (EN: The Registrar)
- **Kim jest:** nie potworem, a funkcją. Zarządza obsadą Taśmy Zero, uzupełniając wakaty. Kogo nagrano wystarczająco często, tego „przenosi się do kadr” i zostaje tylko na taśmie.
- **Gra słów:** „kadry” (dział personalny) i „kadr” (obraz filmowy).
- **Sygnatura wizualna:** bardzo wysoka postać w garniturze, której **głowy nigdy nie widać, bo zawsze jest poza górną krawędzią kadru**. Podniesiesz kamerę wyżej, a szyja urośnie razem z nią. To nasz własny, tani i niemożliwy do zapomnienia obraz.
- **Sygnał:** zanik szumu tła (patrz §9).

### Zebranie 1987
12 listopada 1987 w Domu Kultury „Jutrzenka” odbyło się zebranie kadrowe, na które przyszły 192 osoby. Wszystko nagrano. Nikt nie wyszedł, a pod koniec taśmy na liście obecnych pojawiają się nazwiska, których wtedy nikt nie znał. Są to nazwy graczy.

### Zakończenia [PÓŹNIEJ]
- **A. „Koniec zebrania”:** drużyna niszczy Taśmę Zero. Ekran gaśnie i gra nie wraca do lobby przez dłuższą chwilę; po powrocie wszystkie akta są puste.
- **B. „Etat”:** drużyna przyjmuje stanowisko. Awatary trafiają na stałe do tablicy personelu, a lobby traktuje ich jak Kadrowych.
- **C. „Poza kadrem” (ukryte):** ukończenie finału z minimalną liczbą odtworzeń w całej kampanii. Drużyna wycina się z taśmy; nazwy graczy znikają z list, a nowe sekretne pomieszczenie jest dostępne tylko dla nich.
- **D. „Dubel”:** porażka w finale. Start od nowa z numerem podejścia na tabliczce, a NPC w lobby zachowują się, jakby już to widziały.

### Plan misji (sezon 1)
| # | Tytuł | Miejsce | Nowy pomysł | Hak na koniec |
|---|---|---|---|---|
| 001 **[VS]** | Zebranie | Dom Kultury | Pełna sala na taśmie, koszt odtworzenia | Awatary na widowni, data z przyszłości, migawka autobusu |
| 002 | Kurs 17 | Nocny autobus | Dubler powtarza ruchy gracza | Pętla trasy, przystanek przed blokiem |
| 003 | Pion | Klatka bloku | Numery pięter zależą od taśmy | Drzwi z wizytówką gracza |
| 004 | Turnus | Sanatorium | Dr Wrona, dorysowywanie klatek | Taśma Zero istnieje |
| 005 | Taśma Zero | Archiwum 03 | Lobby staje się misją | Zakończenia |

## 3. Pętla rozgrywki

**Sekundy:** patrz okiem → podnieś kamerę → porównaj.
**Minuty:** nagraj → zdecyduj, czy odtworzyć → użyj wiedzy → uciekaj przed konsekwencją.
**Sesja:** lobby → drużyna → misja (15–25 min) → finałowa taśma → lobby się zmieniło.
**Tygodnie:** nowe misje, kolekcja taśm, sekrety w lobby, alternatywne podejścia („Duble”).

## 4. Mechaniki

Każda ma jeden cel. Co go nie ma, wypada.

### 4.1 Kamera (wizjer) [VS]
| Działanie | Rezultat | Cel |
|---|---|---|
| **Podnieś** (PPM / L2 / przycisk) | Pełnoekranowy wizjer: ramka, REC, licznik. Widać warstwę taśmy | Dwie prawdy |
| **Nagraj** (R / R2 / przycisk) | Zapis do 12 s. Budżet 3 taśm na osobę | Decyzja, co warto nagrać |
| **Odtwórz** (T / Y / przycisk) | Kamera przejmuje obraz i jedzie po nagranej trasie; ciało gracza stoi bez ochrony | Główna decyzja i ryzyko |

**Jak to działa bez przechwytywania obrazu:** to zapis ścieżki kamery (10 Hz), pozycji graczy i stanu świata. Odtworzenie renderuje świat na żywo głównym renderem, ze zmienioną warstwą. Efekty VHS pojawiają się **wyłącznie** w wizjerze i na odtworzeniu, bo tylko tam mają uzasadnienie.

**Trzy poziomy prawdy:**
1. **Oko:** sala pusta.
2. **Wizjer na żywo:** sala pełna, wszyscy patrzą na scenę.
3. **Odtworzenie:** kilka osób odwróconych twarzą do kamery. Tej informacji nie da się zdobyć inaczej.

### 4.2 Pozostałe urządzenia
- **Latarka [VS]:** F / D-pad / przycisk. Stożek światła, widoczny dla drużyny. Nie działa na Kadrowego.
- **Krótkofalówka [VS]:** cztery szybkie komunikaty („Tutaj!”, „Uwaga!”, „Tak”, „Nie”) z ikoną pozycji. Konieczna, bo nie każdy ma czat lub mikrofon. Czat i głos Robloxa działają normalnie.
- **Statyw [PÓŹNIEJ]:** zostawiona kamera kadruje jeden punkt. Poprawia tryb solo.
- **Wykrywacz szumu [PÓŹNIEJ]:** odnajduje źródła dźwięku za ścianą.

Rezygnuję z ulepszeń statystyk sprzętu: psułyby balans i sugerowały pay-to-win.

### 4.3 Eksploracja i interakcje [VS]
`ProximityPrompt` działa na PC, telefonie i kontrolerze bez osobnego kodu. Otwieranie, sprawdzanie siedzeń, zdejmowanie płaszczy, dokumenty.

### 4.4 Kooperacja
| Sytuacja | Co robi drużyna | Solo |
|---|---|---|
| Wizjer i odtworzenie zasłaniają świat [VS] | Jedna osoba ogląda, druga ją osłania | Ryzyko jest większe |
| Taśmę ogląda jedna osoba, siedzenie trzeba znaleźć w sali [VS] | Oglądający mówi „rząd C, siódme”, drugi idzie | Trzeba zapamiętać |
| Drzwi istnieją, gdy ktoś je kadruje [VS] | Jeden trzyma kadr, inni przechodzą | Idziesz, nie spuszczając kadru |
| Ratowanie wyciętego [VS] | Trzymaj go w kadrze 3 s | Powrót przez znacznik montażowy po 30 s |
| Różne informacje [PÓŹNIEJ] | Dwa oskryptowane momenty w misji: każdy widzi inny numer | Numery zgadzają się automatycznie |

### 4.5 Zagrożenie główne: Kadrowy [VS]
Prosty zestaw zasad; gracz odkrywa je grając:

1. **Widać go tylko w wizjerze** (w finale również gołym okiem).
2. **Nie chodzi, tylko przeskakuje** między punktami, gdy nikt go nie kadruje.
3. **Kadrowanie go zatrzymuje, ale długi kontakt „rejestruje” patrzącego** (6 s). Zarejestrowany staje się jego celem. Nie da się więc wygrać, stale się w niego wpatrując; warto zmieniać się w drużynie.
4. **Każde odtworzenie poza pierwszym w misji przybliża go o krok do oglądającego** (pierwsze jest darmowe, by gracz zobaczył, co daje taśma). Na kolejnych odtworzeniach widać go coraz bliżej na samym nagraniu.
5. **Przed skokiem milknie szum.** Cisza to ostrzeżenie (czasem fałszywe).
6. **Dotyk nie zabija, tylko wycina** gracza z kadru (patrz niżej).

Reguły są uczciwe: każdy skok ma ostrzeżenie, a kontakt ma 1,5 s reakcji, podczas której kadrowanie ratuje.

### 4.6 Wycięcie (Off-Frame) [VS]
Zamiast śmierci gracz trafia „poza kadr”:
- Reszta go nie widzi okiem, tylko przez wizjer.
- On widzi świat w chłodnym kolorze, a także warstwę taśmy i Kadrowego przez cały czas.
- Nie może wchodzić w interakcje, ale może komunikować się i **pukać** (dźwięk w swojej pozycji).
- Teammate przywraca go, trzymając w kadrze przez 3 s; po 30 s może też sam dojść do znacznika w foyer.
- Wszyscy wycięci = **koniec taśmy** (porażka).

Dzięki temu nie ma nudy po śmierci, a wycięty staje się cennym zwiadowcą. Wyjaśnia to też tytuł gry.

### 4.7 Pozostałe zagrożenia
- **Błąd proceduralny [VS]:** złe siedzenie lub zły hak przesuwa Kadrowego o krok.
- **Zmiana układu sali [VS]:** w kolejnych podejściach niektóre krzesła są odwrócone tyłem.
- **Fałszywa wskazówka [VS]:** instrukcja Biura mówi „Nie odtwarzaj taśmy”; bez odtworzenia nie da się ukończyć misji. Kolejna instrukcja jest podpisana inaczej niż poprzednie.
- **Zmieniające się pomieszczenia [PÓŹNIEJ]:** zmiany w pokoju poza polem widzenia.

### 4.8 Progresja
| System | Trwałe | Cel |
|---|---|---|
| Odkryte misje [VS] | Tak | Serial |
| Dokumenty i taśmy [VS] | Tak | Składanie fabuły |
| Statystyki (ukończenia, odtworzenia, wycięcia) [VS] | Tak | Tożsamość gracza |
| Zmiany w lobby [VS: jedna] | Tak | Świat reaguje |
| Osiągnięcia [VS: zapis, bez UI] | Tak | Cele długoterminowe |
| Stopień służbowy, kosmetyka [PÓŹNIEJ] | Tak | Długi ogon i monetyzacja |

Stan misji (kto ma szpule, ile było odtworzeń) jest tylko sesyjny i **nie trafia do DataStore**.

## 5. Lobby: Archiwum 03

### 5.1 Pierwsze 3 minuty [VS]
**Stanowisko 03-B** to mały pokój z biurkiem, lampą, telewizorem, krzesłem i zamkniętymi drzwiami.

| Czas | Co się dzieje |
|---|---|
| 0:00 | Bez logo, bez menu. Lampa, szum, ekran CRT z tekstem „Dzień dobry. Proszę usiąść.” |
| 0:15 | Na biurku teczka powitalna: krótkie zasady Biura |
| 0:40 | Na biurku kamera. Prompt „Weź kamerę” odblokowuje podnoszenie |
| 0:50 | **Pierwszy dreszcz:** w wizjerze na pustym krześle ktoś siedzi. Po opuszczeniu i ponownym podniesieniu kamery krzesło jest puste, a sylwetka stoi w innym miejscu |
| 1:30 | Drzwi otwierają się same, gdy gracz podniósł kamerę co najmniej dwa razy |
| 2:00 | Korytarz prowadzi do Hali Rejestrów |

Powracający gracz zaczyna od razu przy drzwiach, a pokój się zmienia po ukończeniu misji.

### 5.2 Hala Rejestrów
| Strefa | Funkcja | Status |
|---|---|---|
| **Główna sala** | Punkt zbiórki, półmrok, regały po sufit | [VS] |
| **Terminal ekspedycji** | Wybór misji, tworzenie drużyny, lista otwartych drużyn | [VS] |
| **Tablica ekspedycji** | Fizyczna tablica z teczkami misji, zablokowane są zaklejone | [VS] |
| **Pokój taśm** | Odkryte dokumenty, odtwarzanie materiałów | [VS: lista dokumentów] |
| **Szatnia personelu** | Personalizacja, kosmetyka, własna szafka | [PÓŹNIEJ: tylko pomieszczenie] |
| **Ukryte pomieszczenie** | Ściana bez drzwi; drzwi widać w wizjerze | [VS] |
| **Tablica personelu** | Zdjęcia awatarów drużyny | [PÓŹNIEJ] |
| **Zajęcia na czas oczekiwania** | Dzwonek na ladzie, telewizor z zakłóceniami, automat z kawą | [VS: dzwonek] |

Brak jasnych przycisków na środku ekranu i sklepu w twarz. Menu są fizycznymi terminalami, a sklep to pokój, do którego trzeba wejść.

### 5.3 Flow drużyny
1. Prompt przy terminalu otwiera panel ekspedycji (ekran terminala w stylu CRT).
2. **Utwórz:** wybór misji; drużyna ma swój kod.
3. **Dołącz:** lista otwartych drużyn na tym serwerze.
4. **Zaproś:** systemowy prompt znajomych, gdy dostępny.
5. **Gotowość:** każdy zaznacza „Gotów”. Lider może wyrzucić.
6. **Start:** tylko lider, gdy wszyscy gotowi. Pojawia się ekran przygotowania i 5 s odliczania z możliwością przerwania.
7. **Teleport:** wszyscy na ten sam serwer zarezerwowany, z ekranem ładowania „Przewijanie taśmy…”.
8. **Błąd:** 3 próby z przerwą, a potem komunikat i powrót do panelu drużyny.
9. **Powrót:** po misji wszyscy trafiają do Hali. Rozłączony gracz po powrocie do huba dostaje propozycję powrotu do misji.

## 6. Pierwsza misja: 001 „Zebranie”

### Wprowadzenie
Teczka: „Dom Kultury »Jutrzenka«. Zebranie z 12.11.1987. Taśma uszkodzona. Zadanie: zweryfikować listę obecności i sporządzić materiał. **Prosimy nie odtwarzać taśmy na miejscu.**”

### Lokalizacja
Prowincjonalny dom kultury, dziś pusty, z zachowanym wyposażeniem. Turkusowa wykładzina, boazeria, zielonkawe świetlówki.

```
                 [ ARCHIWUM (ukryte) ]
        ┌────────[ ściana sceny + drzwi tylko w kadrze ]───────┐
        │              SCENA: biurko, dzwonek, ekran           │
  ┌─────┤                                                      │
  │ K   │   rzędy A–L, 16 miejsc w rzędzie, przejście środkiem │
  │ O   │                                                      │
  │ T   │                      SALA                            │
  │ A   │                                                      │
  │ R   │                                                      │
  │ Y   │                                                      │
  └─────┤                                                      │
        └───────┬──────[ KABINA nad foyer, okno ]───┬──────────┘
        rampa ─▶│             FOYER (start)         │ SZATNIA (haki 1–40)
                └───────────────────────────────────┘
```

Pętla sala → korytarz → scena pozwala uciekać, zamiast utknąć.

### Zagadka „Protokół obecności”
1. **Nagraj rzędy** w sali. Wizjer na żywo pokazuje pełną widownię, ale wszyscy patrzą na scenę.
2. **Odtwórz.** Na taśmie 3 osoby (spośród sfilmowanych) są odwrócone do kamery, z czarnym paskiem na oczach. Trzeba sfilmować właściwą część sali, więc czasem jedno nagranie nie wystarczy.
3. **Znajdź te siedzenia** gołym okiem i sprawdź pod nimi: znajdziesz numerek do szatni.
4. **W szatni** pod numerem wisi płaszcz, a w nim szpula filmu (A, B, C).
5. **W kabinie** załaduj 3 szpule do projektora. Ekran w sali pokaże film z drzwiami w tylnej ścianie sceny.
6. **Kadruj ścianę.** Gołym okiem to ściana, a w wizjerze są tam drzwi. Gdy ktoś je kadruje, można przez nie przejść.
7. **W Archiwum** jest rejestr obecnych, a na nim nazwy graczy. Przeczytanie uruchamia kulminację.
8. **Kulminacja:** widownia i Kadrowy są już widoczni bez kamery, odwróceni w stronę sceny. Trzeba wrócić i przytrzymać dzwonek, by zamknąć zebranie.

### Zmiana po rozwoju misji
Zagadka ma teraz dwa dodatkowe etapy. Po wyjęciu ostatniej szpuli **gaśnie prąd**: bezpiecznik jest w piwnicy (wejście z korytarza z kotarami), a jego kod trzyma pierwszy rząd widowni, widoczny tylko przez wizjer ze sceny. Każdy gracz dostaje inne cyfry, więc drużyna musi je sobie podać. Potem szpule trzeba załadować we właściwej kolejności, którą podaje **magnetofon w gabinecie dyrektora**; jego odtworzenie liczy się jak każdy seans. Tabela poniżej pokazuje pierwotny plan i wymaga przeliczenia po testach z ludźmi.

### Przebieg minutowy (drużyna 2-osobowa, 20 min)
| Czas | Miejsce | Wydarzenia | Dźwięk | Cel emocji |
|---|---|---|---|---|
| 0:00–1:00 | Foyer | Spokojnie. Teczka, cel, kasa biletowa, plakat „Zebranie”. Jasno jak na tę grę | Świetlówka, szum, kroki na wykładzinie | Fałszywe bezpieczeństwo |
| 1:00–2:30 | Foyer | Radio: „Sprawdźcie sprzęt”. W wizjerze: na ławce ktoś siedzi, a okiem nikogo tam nie ma | Klik kamery, silnik taśmy | Pierwszy dreszcz |
| 2:30–4:00 | Drzwi do sali | Wejście. Pusta sala, 192 krzesła zwrócone ku scenie | Pogłos, cichnie szum | Skala i pustka |
| 4:00–5:00 | Sala | **MOMENT:** podniesienie kamery, a sala jest pełna | Ledwo słyszalny oddech wielu osób, tylko w wizjerze | Główny obraz gry |
| 5:00–8:00 | Sala | Nagranie i pierwsze odtworzenie; widać odwrócone osoby. Dalej na odtworzeniu, na końcu rzędu, stoi wysoka postać | Zwolniony dźwięk taśmy | Zrozumienie mechaniki |
| 8:00–12:00 | Sala i szatnia | Szukanie siedzeń i płaszczy. **Pierwsze pojawienie się:** przy kolejnym odtworzeniu postać jest bliżej, a w wizjerze stoi też w sali | **Pierwsza cisza** tuż przed skokiem | Odkrycie kosztu |
| 12:00–14:00 | Kabina | Rampa, projektor, załadowanie szpul. Przez okno widać salę; ekran pokazuje drzwi | Terkot projektora | Oddech i mocny obraz |
| 14:00–16:00 | Scena | Kadrowanie ściany, przejście | Niska nuta tylko w wizjerze | Współpraca |
| 16:00–17:30 | Archiwum | Regały, dokumenty, rejestr z imionami graczy. **Cisza absolutna** | Nic. Dosłownie brak dźwięku poza krokami | Osobista groza |
| 17:30–19:30 | Sala | **Kulminacja:** wyjście na scenę, widownia widoczna bez kamery. Jeden, potem drugi gracz może zostać wycięty | Narastający dźwięk wstających ludzi, jedyny motyw muzyczny | Szczyt |
| 19:30–20:00 | Scena | Dzwonek, odcięcie dźwięku, czerń | Dzwonek i absolutna cisza | Ulga |
| Koniec | Taśma | **Finałowa taśma:** sala, a wśród widowni awatary drużyny, patrzące w kamerę. Napis: data z przyszłego tygodnia. Migawka: nocny autobus, którego nie widzieli | Szum taśmy | **Hak** |

### Sekrety
- **Dokument: lista obecności** z przekreśleniami [VS].
- **Dokument: notatka Wrony** w kabinie: „Klatki 14–22 dorysowałam ręcznie” [VS].
- **Dokument: rejestr** w Archiwum [VS].
- **Taśma „Ławka”:** nagranie ławki w foyer przed wejściem do sali daje dodatkowy dokument [PÓŹNIEJ].

### Podejście alternatywne (Dubel)
`Take` zależy od liczby wcześniejszych ukończeń w drużynie.

| | Dubel 1 | Dubel 2 | Dubel 3+ |
|---|---|---|---|
| Szyk siedzeń | 3 losowe | Inne 3 losowe | Inne 3 losowe |
| Drzwi w scenie | Losowo lewo/prawo | jw. | jw. |
| Kadrowy | Start w oddali, wolniejszy | Start bliżej, od razu przeskakuje | Szybszy, startuje w foyer |
| Anomalia | Sala normalna | **Co czwarty rząd odwrócony tyłem do sceny** | Odwrócone rzędy i **wizjer pokazuje salę jako pustą** do czasu odtworzenia |
| Tekst teczki | Wersja 1 | „Prosimy nie odtwarzać taśmy po raz drugi.” | „Wiemy, że już tu byliście.” |

Dzięki temu powrót do misji jest rozpoznawalną „kolejną wersją zdarzeń”, a nie tylko tą samą zagadką.

## 7. Kierunek wizualny

**Styl: instytucjonalny surrealizm.** Proste, czyste bryły, realistyczne proporcje, kilka mocnych materiałów. Nie gonimy fotorealizmu; wygrywamy światłem i kompozycją.

### Paleta
| Rola | Kolor | Hex |
|---|---|---|
| Wykładzina (znak rozpoznawczy) | Głęboki turkus | `#0E3A3F` |
| Drewno | Ciepły fornir | `#6B3A22` |
| Ściany | Brudny beż | `#A89A80` |
| Sufit | Szara płyta | `#54575A` |
| Światło | Zielonkawa świetlówka | `#D8E6D2` |
| Światło ciepłe (tylko akcenty) | Żarówka | `#FFC98A` |
| Cień | Granatowa czerń | `#0A0E14` |
| Sygnał REC | Czerwień | `#D9342B` |

**Zasada 60-30-10:** 60% chłodnego półcienia, 30% neutralnych ścian, 10% ciepłego akcentu. Ciepłe światło to zawsze punkt zainteresowania.

### Światło
Jedna do dwóch plam na pomieszczenie. Każde pomieszczenie ma być czytelne bez latarki. Latarka pomaga, ale nie jest konieczna.

**Punkt wyjścia ustawień Lighting (do strojenia na ekranie):**
```
Technology: ShadowMap        Brightness: 1.2
ClockTime: 0                 GlobalShadows: true
Ambient: 16,19,24            OutdoorAmbient: 8,10,14
EnvironmentDiffuseScale: .15 EnvironmentSpecularScale: .3
Atmosphere: Density .32, Offset 0, Haze 1.5, Glare 0,
            Color 40,52,58, Decay 12,16,20
ColorCorrection: Contrast .08, Saturation -.12, Tint 245,250,245
Bloom: Intensity .35, Size 18, Threshold 1.6
```

**Warstwa wizjera:** Saturation −0,45, Contrast +0,18, chłodny Tint. **Odtworzenie:** dodatkowo proporcje 4:3, ziarno jako UI, DepthOfField tylko tu. **Poza kadrem:** Saturation −0,9, niebieski Tint.

Na słabszych urządzeniach klimat ma się opierać na geometrii i `PointLight`/`SpotLight`. Post-processing jest dodatkiem i gra musi wyglądać dobrze bez DepthOfField.

### Geometria i materiały
- Dużo pustej podłogi, niskie sufity w foyer, wysokie w sali. Kontrast skali przy wejściu.
- Powtarzalność (krzesła, płyty) daje poczucie instytucji i jest tania w renderze.
- Materiały wbudowane: Fabric (wykładzina, kotary), Wood, SmoothPlastic, Concrete. `SurfaceAppearance` tylko dla hero assetów.
- `ParticleEmitter`: bardzo oszczędnie, kurz w snopie projektora. `Beam`: tylko snop projektora.

### Postacie
- **Gracze:** awatary Robloxa bez zmian; to wzmacnia finałową taśmę. Kosmetyka Biura (identyfikator, plakietka) jako akcesorium [PÓŹNIEJ].
- **Widownia:** stylizowane, uproszczone sylwetki w szarych garniturach. Odwróceni mają **czarny pasek na oczach**, jak na anonimizowanych zdjęciach. To nasz motyw.
- **Kadrowy:** bardzo wysoki, wąski garnitur, nienaturalnie długa szyja znikająca w górze kadru.

### UI
Maszyna do pisania/monospace, beż na czerni, jeden czerwony akcent. HUD w misji znika, gdy nie jest potrzebny. Zero kolorowych przycisków.

### Assety: co skąd
| Asset | Źródło | Slice |
|---|---|---|
| Krzesła, biurka, ściany, regały, rampy | Geometria Luau (szary box) | **Gotowe proceduralnie** |
| Widownia, Kadrowy | Części, finalnie **Blender (ręcznie)** | Szary box |
| Kamera (model w ręku) | **Blender** | Pominięta; wizjer pełnoekranowy |
| Tekstury wykładziny, tapety, plakatów | Własne grafiki/tekstury 2D | Materiały wbudowane |
| Płaszcze, wieszaki | **Creator Store** po audycie albo proste części | Proste części |
| Ambienty i efekty | **Własne nagrania/synteza** docelowo; Creator Store jako tymczasowe | Tymczasowe po weryfikacji |
| Ikona, miniatury | **Ręcznie** ze sceny gry | Poza slice |

## 8. Warstwy dźwięku

Dźwięk jest częścią rozgrywki. **Główna zasada: zawsze jest szum, więc cisza staje się zdarzeniem.**

| # | Warstwa | Przykłady | Technika |
|---|---|---|---|
| 1 | Ambient | Niski pomruk budynku, świetlówki | Pętla 2D, głośność wg strefy |
| 2 | Przestrzenne | Pojedyncze trzaski, wentylacja | 3D `Sound` w częściach, RollOff |
| 3 | Otoczenie | Skrzypienie krzesła, kapanie | Losowe jednorazowe, 3D |
| 4 | Anomalie | Oddech widowni **tylko w wizjerze** | Włączane z warstwą wizjera |
| 5 | Przeciwnik | Stłumiony krok, szept papieru | 3D z `EqualizerSoundEffect` za ścianą |
| 6 | Interakcje | Klik dzwonka, wieszak, teczka | Krótkie, suche |
| 7 | Urządzenia | Silnik taśmy, REC, przewijanie | 2D, „bliskie” |
| 8 | Muzyka | Tylko kulminacja i finałowa taśma | 2D, jedna fraza |

**Parametry:**
- **Kierunkowość:** 3D `Sound` na elementach świata.
- **Odległość:** `RollOffMode.InverseTapered`, zasięg według roli.
- **Pogłos:** `SoundService.AmbientReverb` dobierany do strefy (foyer: Room, sala: Auditorium, archiwum: bez pogłosu).
- **Za ścianą:** gdy raycast do źródła jest zablokowany, włącz EQ z obciętymi wysokimi tonami.
- **Tylko w sytuacji:** warstwa 4 wyłącznie w wizjerze, a na odtworzeniu pitch taśmy jest obniżony.

**Reżyser ciszy (`AudioController`):**
- `Normal`: ambient na poziomie strefy.
- `Silence`: płynne wyciszenie ambientu w 0,4 s, 2 s przed skokiem Kadrowego; po skoku powrót w 3 s.
- `FalseSilence`: czasem cisza bez skoku, by nie dało się jej w pełni ufać, ale rzadko (po pierwszych 2 prawdziwych).
- `Absolute`: Archiwum. Zero ambientu, tylko kroki.

Dźwięki z Creator Store są w slice **tymczasowe**. Przed premierą wymieniamy je na własny, spójny zestaw.

## 9. UX i interfejs

### Sterowanie
| Akcja | PC | Telefon/tablet | Kontroler |
|---|---|---|---|
| Interakcja | E | Dotknij prompt | X |
| Kamera | PPM | Przycisk | L2 |
| Nagraj | R | Przycisk (gdy kamera w górze) | R2 |
| Odtwórz | T | Przycisk | Y |
| Latarka | F | Przycisk | D-pad góra |
| Komunikaty | 1–4 | Przycisk + wybór | D-pad lewo/prawo/dół, B |
| Pukanie (poza kadrem) | K | Przycisk | A |

### Ekrany
- **HUD misji [VS]:** w lewym górnym rogu krótki cel. Licznik taśm tylko przy kamerze. Status drużyny pojawia się, gdy ktoś jest wycięty. Komunikaty radiowe jako napisy na dole.
- **Wizjer [VS]:** narożniki kadru, `● REC`, licznik czasu, liczba taśm.
- **Odtworzenie [VS]:** pasy 4:3, `▶ PLAY`, licznik odtworzenia tej taśmy, drobne pasy zakłóceń.
- **Terminal [VS]:** zielono-bursztynowy panel CRT z listą misji, drużyn i członków.
- **Ekran przygotowania [VS]:** czerń, lista członków, misja, odliczanie, przycisk „Przerwij”.
- **Ładowanie [VS]:** „Przewijanie taśmy…”, licznik.
- **Koniec [VS]:** finałowa taśma, potem karta raportu: czas, odtworzenia, wycięcia, dokumenty.
- **Archiwum dowodów [VS: lista]:** dokumenty posegregowane, z pustymi miejscami sugerującymi kolejne.
- **Menu główne:** celowo go nie ma. Gra od razu zaczyna się w pokoju, a ustawienia są w menu Robloxa lub na terminalu.

Tekst ma minimalnie 14 px na telefonie, kluczowe akcje działają bez koloru jako jedynego sygnału, a przyciski dotykowe mieszczą się w strefie kciuka i szanują `GuiInset`.

## 10. Regrywalność i monetyzacja

### Retencja
| Mechanizm | Retencja | Koszt | Decyzja |
|---|---|---|---|
| Duble (warianty misji) | Wysoka | Niski | **[VS]** |
| Kolejne rozdziały | Bardzo wysoka | Wysoki | Główny silnik; cykl 6–8 tyg. |
| Kolekcja dokumentów i taśm | Średnia | Niski | **[VS: podstawa]** |
| Sekrety w lobby | Średnia, wysoka społecznie | Niski | **[VS: jeden]** |
| Ukryte zakończenia | Wysoka w końcówce | Średni | Przy M005 |
| Osiągnięcia | Średnia | Niski | Po VS |
| Poziom konta (Stopień służbowy) | Średnia | Niski | Po VS, wyłącznie kosmetyczny |
| Codzienne nagrody | Niska jakościowo, psuje klimat | Niski | **Odrzucam** |

### Monetyzacja (bez przewagi)
| Propozycja | Monetyzacja | Retencja | Ryzyko dla klimatu | Decyzja |
|---|---|---|---|---|
| Warianty kamery (obudowa, kolor) | Wysoka: widoczne dla drużyny | Średnia | Niskie | Po VS |
| Personalizacja własnej szafki/stanowiska | Średnia | Wysoka | Niskie | Po VS |
| Stroje i identyfikatory Biura | Średnia | Niska | Niskie | Po VS |
| Serwery prywatne | Niska, ale prosta | Średnia | Brak | Tak (VIP Roblox) |
| Pakiet drużynowy (wspólna naszywka, filtr ramki) | Średnia | Średnia, społeczna | Niskie | Po VS |
| Dodatkowe taśmy, baterie, „ożywienie” | Wysoka krótkoterminowo | Ujemna | **Wysokie, pay-to-win** | **Nigdy** |
| Paid random items | Różna | Ujemna | Wysokie, ryzyko regulacyjne | **Nigdy** |

Oceny są szacunkami przed danymi; zweryfikujemy je analityką po premierze. Sklep to pomieszczenie w lobby, nie okno na ekranie.

## 11. Świadome rezygnacje i ryzyka

| Ryzyko | Ocena | Zabezpieczenie |
|---|---|---|
| Gracze nie zrozumieją, że odtworzenie przybliża Kadrowego | Wysokie | Sygnał dźwiękowy i tekst radia po 1. odtworzeniu. Test VS |
| Wizjer ciągle w górze | Średnie | Rejestracja po 6 s, węższe pole widzenia, efekt dźwiękowy |
| Solo jest za trudne | Średnie | Znacznik montażowy, wolniejszy Kadrowy solo |
| 192 sylwetki na telefonie | Średnie | Pomiar; w razie czego mniej części i widoczność tylko przód sali |
| Zapamiętywanie miejsc frustruje | Średnie | Znaki rzędów i numery przy siedzeniach, wskazówki |
| Marka zależy od wykonania, a proceduralny szary box nie straszy tak jak finalna oprawa | Wysokie | VS testuje mechanikę; art pass dopiero po potwierdzeniu |
