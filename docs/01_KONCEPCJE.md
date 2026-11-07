# 01. Trzy koncepcje i wybór kierunku

## Krytyka punktu wyjścia

Koncept „Poza Kadrem” ma mocny hak („rzeczywistość odtwarza nagrania”), ale w pierwotnej formie ma cztery słabości:

1. **Kamera pokazująca ukryty świat to już znany trop** (Fatal Frame, Content Warning, Backrooms VHS). Sama w sobie nie jest wyróżnikiem.
2. **Odtwarzanie nagrania nie ma kosztu.** Bez kosztu gracz przewija do skutku i napięcie znika.
3. **„Nie wszyscy widzą to samo”** w pełnej wersji generuje tysiące kombinacji stanów. Trzeba to ograniczyć do kilku oskryptowanych momentów.
4. **Sylwetka, która zbliża się przy każdym odtworzeniu**, jest świetnym obrazem, ale bez konsekwencji w świecie to tylko efekt.

Rozwiązanie to jedna decyzja: **odtworzenie taśmy przesuwa przeciwnika w rzeczywistości.** Informacja kosztuje bezpieczeństwo, a gracz sam wywołuje zagrożenie.

## Koncepcja A: POZA KADREM (rozwinięta)

- **Fantazja:** jesteście asystentami Biura Ciągłości i dokumentujecie „błędy ciągłości” rzeczywistości.
- **Rdzeń:** oko pokazuje teraźniejszość, wizjer pokazuje taśmę. Część prawdy widać dopiero na odtworzeniu, a każde odtworzenie przybliża Kadrowego.
- **Moment do pokazania:** pusta sala, podnosisz kamerę i sala jest pełna.
- **Kooperacja:** osoba przy kamerze i osoba idąca bez kamery mają różne informacje; wycięty gracz widzi prawdę i może podpowiadać pukaniem.
- **Ryzyko:** złożoność pierwszego kontaktu i koszt jakości przestrzeni.

## Koncepcja B: REGULAMIN

- **Fantazja:** nocna zmiana w biurowcu instytucji. Każdy gracz dostaje inną stronę regulaminu, a jedna z zasad jest fałszywa.
- **Rdzeń:** gracze zestawiają swoje zasady głosem lub czatem i muszą ustalić, która kłamie. Złamanie zasady wywołuje byt.
- **Moment do pokazania:** „zasada 7 jest kłamstwem” i wybór na końcu odcinka.
- **Mocne strony:** tani w produkcji, naturalnie serialowy, świetny pod krótkie filmy.
- **Słabe strony:** po poznaniu zasad powtórka traci wartość, więc wymaga ciągłej produkcji treści. Mocno zależy od komunikacji, a część graczy ma ograniczony czat. Rdzeń łatwo skopiować.

## Koncepcja C: ZASTĘPSTWO

- **Fantazja:** w drużynie 4–8 osób ktoś jest już kopią. Gra nagrywa ruch graczy i wypuszcza ich sobowtóry.
- **Rdzeń:** dedukcja społeczna z NPC odtwarzającym prawdziwe ruchy i graczem-oszustem.
- **Moment do pokazania:** „idziesz za przyjacielem, po czym przyjaciel pisze, że jest gdzie indziej”.
- **Mocne strony:** ogromny potencjał viralowy, wysoka regrywalność.
- **Słabe strony:** wymaga stałej populacji i 6+ graczy, jest podatna na trolling, słabo niesie fabułę, wchodzi w zatłoczoną niszę gier asymetrycznych. Najdroższa w balansie.

## Ocena

Skala 1–10 (10 = najlepiej; „koszt” 10 = najtaniej). Oceny to mój osąd, nie pomiar.

| Kryterium | Waga | A: Poza Kadrem | B: Regulamin | C: Zastępstwo |
|---|---:|---:|---:|---:|
| Oryginalność | 25% | 9 | 7 | 6 |
| Potencjał viralowy | 20% | 9 | 8 | 9 |
| Retencja | 25% | 7 | 5 | 7 |
| Wykonalność techniczna | 15% | 7 | 9 | 5 |
| Koszt produkcji | 15% | 5 | 8 | 4 |
| **Wynik ważony** | | **7,60** | **7,15** | **6,40** |

Różnica między A i B jest mała, więc decyzję niesie argument jakościowy, nie sam wynik.

## Decyzja: A, z elementami B i C

**Dlaczego A:**
- Jako jedyna ma mechanikę, której nie da się opisać tytułem innej gry: *„im częściej oglądasz, tym bliżej jest”*.
- Jeden pomysł spina fabułę, przeciwnika, zagadki, UI i uzasadnienie efektów analogowych.
- Daje mocny obraz do miniatury i krótkiego filmu (pełna sala w wizjerze).
- Rdzeń da się zweryfikować tanio: rzędy prostych sylwetek i jedna sala wystarczą, by sprawdzić, czy to straszy.

**Co bierzemy z pozostałych:**
- Z B: krótkie zasady Biura w lobby i na taśmach; zasady jako narzędzie fabuły. W pierwszej misji jedna z instrukcji okazuje się nieprawdziwa.
- Z C: odtwarzanie prawdziwych ruchów graczy jako duchy na taśmie, a w misji 002 „Dubler”, który powtarza ruch gracza sprzed kilkudziesięciu sekund.

**Co odrzucamy:**
- Odtwarzanie głosu graczy (`AudioRecorder` niedostępny, a mikrofonu i tak nie da się nagrać; do tego ryzyko prywatności).
- Prawdziwy obraz z ekranu (niewykonalne).
- Pełny „każdy widzi inaczej” przez całą misję (eksplozja stanów).

## Warunek weryfikacji

Kierunek jest **hipotezą do testu**, nie pewnikiem. Testy po Vertical Slice:

1. Czy gracz bez instrukcji rozumie, że odtworzenie przybliża Kadrowego? (cel: ≥ 70% po pierwszej misji)
2. Czy pierwsze podniesienie kamery w sali wywołuje reakcję? (obserwacja 5 osób)
3. Czy drużyna unika odtwarzania i dyskutuje, czy warto? To główny sygnał, że koszt działa.

Jeśli pkt 3 nie zachodzi, trzeba zmienić mechanikę, zanim powstanie kolejna misja.

## Tytuł

**HEADCOUNT** (decyzja właściciela z 2026-11-07, wcześniej roboczo POZA KADREM / OFF FRAME). „Poza kadrem” zostaje nazwą stanu w grze i ukrytego zakończenia. Nie sprawdziłem dostępności nazwy na Robloxie ani znaków towarowych.
