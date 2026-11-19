# 10. Test filmikiem: czy hak „The Extra” działa, zanim powstanie prototyp

Stan na 2026-11-19. Kierunek gry opisuje `09_GDD_V2.md`. Ten dokument opisuje tani test rynku: 15-sekundowy pionowy klip nagrany w silniku, opublikowany w trzech wariantach haka.

## 1. Co sprawdzamy

**Hipoteza:** zasada „jeden z was nie jest człowiekiem, widać to tylko w kamerze” w 15 sekundach wywołuje u widza chęć zagrania.

**Sygnał, który się liczy:** komentarze z pytaniem o grę („jak się nazywa?”, „gdzie zagrać?”, „kiedy wyjdzie?”), udostępnienia i oglądanie do końca. Same polubienia mówią mało.

**Koszt:** 1–2 dni zamiast 2–3 tygodni prototypu.

## 2. Film

**Idea w jednym zdaniu:** idziesz za kolegą, kolega pisze, że jest gdzie indziej, podnosisz kamerę i widzisz, kim jest ten przed tobą.

**Benchmark:** krótkie horrory z zasadami z `00_RESEARCH.md` (ref. 3: jedna reguła, napisy po kilka słów, wybór na końcu). Bierzemy rytm i czytelność. Nie bierzemy samego jumpscare'u ani wyglądu cudzych postaci.

**Rozważone struktury:**
1. **POV za kolegą, wiadomość na czacie, podniesienie kamery** (wybrana). Sprzedaje dokładnie nową zasadę: ukryty gracz i kamera jako jedyny dowód.
2. Pusta sala, podniesienie kamery i pełna widownia. Odrzucona: to obraz ze starego kierunku i nie pokazuje ukrytego gracza.
3. Podzielony ekran: oko i kamera obok siebie. Odrzucona: tłumaczy zamiast straszyć, a pierwszy kadr jest słabszy.

**Ustawienia:** 9:16, 15 s, napisy w świecie gry (hak i czat), stała rzecz w kadrze to kolega idący korytarzem. Jeden kolor akcentu: czerwień REC, tylko przy „9” i pod tytułem. Moment kulminacyjny (podniesienie kamery) wypada w 7,1 s, ciągnie się do 11,4 s i jest najgłośniejszym momentem.

### Oś czasu (ta sama tabela `T` jest w `src/mission/client/Teaser.luau`)

| Czas | Co widać | Co widz ma zrozumieć | Dźwięk |
|---|---|---|---|
| 0,0 | Korytarz z kotarami, kolega idzie przed nami. Pierwsza linia haka już na ekranie | O co chodzi (hak) | szum budynku, kroki |
| 1,1 | Druga linia haka | Coś się nie zgadza | kroki |
| 3,2 | Hak znika | | |
| 3,5 | Czat: „{imię}: where r u?? im in the basement” | Kolega jest gdzie indziej | |
| 4,3 | Kolega zatrzymuje się na podwyższeniu, plecami do nas | Kim on jest? | cichnięcie kroków |
| 6,2 | Szum budynku urywa się (w grze to ostrzeżenie przed Kadrowym) | Zaraz coś się stanie | **cisza** |
| 6,5 | Czat znika | | |
| 7,0 | Podniesienie kamery, migawka | Patrzymy przez kamerę | klik kamery |
| 7,07 | W wizjerze zamiast kolegi stoi wysoka postać bez głowy w kadrze, zwrócona do nas | **To nie jest kolega** | **uderzenie (najgłośniej)**, dron |
| 7,4 | Zapala się REC | Nagrywamy | silnik taśmy |
| 8,0–10,4 | Kamera powoli unosi się wzdłuż postaci, szyja rośnie razem z kadrem | Głowy nie da się zobaczyć | dron |
| 10,6 | Postać przeskakuje tuż przed obiektyw, błysk, wstrząs | Przyspieszenie | głębokie uderzenie |
| 11,4 | Czerń | | cisza |
| 11,8 | HEADCOUNT i czerwona linia | Nazwa gry | dzwonek (domyka zebranie) |
| 12,4 | „One of you isn't human.” | Zasada | |
| 12,9 | „IN-ENGINE CONCEPT · IN DEVELOPMENT FOR ROBLOX” | Uczciwa etykieta: to koncept, nie gotowa gra | |
| 15,0 | Koniec | | |

### Warianty haka (klawisze 1, 2, 3 przed startem)

| Wariant | Linia 1 | Linia 2 | Czat |
|---|---|---|---|
| **A** | THERE WERE 8 OF US. | THE HEADCOUNT SAID **9**. | where r u?? im in the basement |
| **B** | MY FRIEND WAS IN THE BASEMENT. | SO WHO WAS I FOLLOWING? | bro im STILL in the basement. where r u |
| **C** | ONE OF US ISN'T HUMAN. | ONLY THE CAMERA CAN TELL. | where r u?? im in the basement |

A sprzedaje nazwę gry, B ciekawość, C samą zasadę. Nie wiemy, który zadziała, i właśnie to mierzymy.

## 3. Nagranie w Studio

1. Zbuduj miejsce: `python scripts/check.py` (albo `rojo build mission.project.json -o build/Mission.rbxl`) i otwórz `build/Mission.rbxl` w Studio.
2. W **Workspace** dodaj atrybuty (Properties → Attributes → +):
   - `Teaser` (boolean) = true, **wymagany**,
   - `TeaserFriendUserId` (number): awatar „kolegi”. Domyślnie twój własny. Cudzego konta używaj tylko za zgodą właściciela.
   - `TeaserFriendName` (string): imię na czacie. Domyślnie nazwa tego konta.
   - `TeaserHook` (string): A, B albo C (można też wybrać klawiszem).
3. Ustaw podgląd telefonu w pionie: **Test → Device** i telefon w orientacji pionowej (najlepiej o proporcjach 9:16).
4. **Play** (F5). Po chwili na dole pojawi się `HOOK A · 1 / 2 / 3 PICKS · P ROLLS`.
5. Zacznij nagrywać ekran: Win+Alt+R (Xbox Game Bar) albo OBS z nagrywaniem okna i dźwięku.
6. Naciśnij **P**. Film trwa 15 s. Po końcu **R** wraca na start, więc można nagrać kolejny wariant.
7. Nagraj każdy wariant 2–3 razy i wybierz najlepsze ujęcie.

Scena działa **tylko w Studio i tylko z atrybutem `Teaser`**. W opublikowanej grze ten kod się nie uruchamia.

## 4. Obróbka (ffmpeg jest zainstalowany na tym komputerze)

Jeśli nagranie jest poziome, a podgląd nie był w pionie, wytnij środek 9:16, przytnij do 15 s i wyrównaj głośność. `-ss` to sekunda nagrania, w której naciśnięto P:

```powershell
ffmpeg -ss 2.0 -i nagranie.mp4 -t 15 -vf "crop=trunc(ih*9/16/2)*2:ih,scale=1080:1920" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -af "loudnorm=I=-14:TP=-1" -c:a aac -b:a 192k hook_A.mp4
```

Gdy nagrywasz w podglądzie pionowym, pomiń `crop` i zostaw samo `scale=1080:1920`.

**Przed publikacją sprawdź na telefonie:**
- pierwszy kadr: hak czytelny bez dźwięku,
- napis z czatu da się przeczytać w czasie, gdy jest widoczny,
- w kadrze nie ma kursora, ikony menu Robloxa ani okien Studio,
- głowy postaci nigdy nie widać.

## 5. Publikacja

- **Gdzie:** TikTok, YouTube Shorts i Instagram Reels. Wszystkie trzy warianty na każdej platformie.
- **Kiedy:** jeden wariant dziennie, o tej samej godzinie (po szkole, 16:00–19:00 czasu odbiorców), przez 3 dni. Bez płatnej promocji, żeby porównanie było uczciwe.
- **Opis:** pytanie, które zaprasza do komentarza, np. „Would you play this on Roblox? 👀”, plus 3–5 tagów: `#roblox #robloxhorror #horror #gamedev`.
- **Uczciwość:** w filmie jest etykieta konceptu. W opisie nie obiecujemy daty premiery.
- **Komentarze:** odpowiadać w pierwszej godzinie. Pytania o grę to nasz główny sygnał, więc warto je podtrzymać, np. „follow to get the playtest first”.

## 6. Pomiar i decyzja (po 72 godzinach od publikacji)

Dla każdego klipu zapisz: wyświetlenia, średni czas oglądania, odsetek obejrzeń do końca, udostępnienia, zapisy, wszystkie komentarze, komentarze z pytaniem o grę i nowe obserwacje.

Nowe konto bez historii dostaje mało wyświetleń, więc liczą się **proporcje i porównanie wariantów**, nie surowe liczby. Progi poniżej to nasze założenia, nie branżowe benchmarki:

| Wynik | Warunek | Co robimy |
|---|---|---|
| **Zielone światło** | któryś wariant: średnio obejrzane ≥ 70% długości **i** komentarze z pytaniem o grę ≥ 1 na 1000 wyświetleń albo udostępnienia ≥ 1% wyświetleń | budujemy prototyp z `09_GDD_V2.md` §12, zwycięski hak idzie do opisu gry i miniatury |
| **Żółte** | dobre oglądanie, ale prawie brak pytań o grę | hak przyciąga, zasada nie. Nagrywamy 2–3 nowe warianty z mocniejszą sceną zasady i powtarzamy |
| **Czerwone** | średnio obejrzane < 50% we wszystkich wariantach i brak pytań o grę | wracamy do koncepcji, zanim powstanie kod |

**Test jakościowy (równolegle, bez publikacji):** pokaż klip 5–10 osobom w wieku 10–14 lat, bez wyjaśnień, i zapytaj: „O czym jest ta gra?”. Jeśli większość powie coś w rodzaju „jeden z graczy jest potworem i widać go tylko w kamerze”, zasada jest czytelna.

## 7. Czego nie sprawdzono

- Scena nie została uruchomiona w Studio. Na tym komputerze nie ma `rojo`, `lune`, `selene` ani `stylua`, więc nie przeszła też bramek z `scripts/check.py`. Pierwsze uruchomienie może wymagać poprawek.
- Kadr korytarza (ustawienie kamery, kotary, oświetlenie) jest policzony z `Core/Layout`, a nie obejrzany. Pozycje i tempo są stałymi na górze `Teaser.luau` i łatwo je zmienić.
- Animacja chodu kolegi używa domyślnych animacji R15. Jeśli stopy się ślizgają, zmień `WALK_ANIMATION_STUDS`.
- Ukrycie górnego paska Robloxa (`TopbarEnabled`) może nie zadziałać w nowszym Studio. Wtedy trzeba go wykadrować.
- Postać to obecny tymczasowy model Kadrowego. Przed publiczną premierą GDD zakłada model zrobiony ręcznie, ale do testu haka wystarczy ten.
- Dźwięki to tymczasowe dźwięki z Creator Store; nikt ich jeszcze nie odsłuchał.
