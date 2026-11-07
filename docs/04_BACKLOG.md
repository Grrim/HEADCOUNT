# 04. Backlog Vertical Slice

Kolejność zadań wynika z ryzyka. Najpierw sprawdzamy mechanikę, która może zabić projekt. Każdy kamień milowy kończy się czymś, co da się zagrać.

Status aktualny: patrz `05_STATUS.md`. `[x]` znaczy „napisane”; zakres testów każdego punktu opisuje status. T26, T27, T28 (zapis) i T30 nie zostały uruchomione w pełni.

## M0: Fundament
- [x] T01 Projekty Rojo (hub, mission), `rokit.toml`, selene, stylua
- [x] T02 `scripts/check.py` obejmujący oba projekty
- [x] T03 Runner Lune i pierwszy test

## M1: Czysta logika (test w Lune)
- [x] T04 `Rng`, `Seats`
- [x] T05 `Puzzle`, `Take`
- [x] T06 `Framing`, `Graph`, `Registrar`
- [x] T07 `Tape`
- [x] T08 `Flow`
- [x] T09 `Party`, `Progress`, `RateLimit`

## M2: Rdzeń misji (najważniejszy test koncepcji)
- [x] T10 Geometria misji i oświetlenie
- [x] T11 Wizjer i warstwa widowni: **podniesienie kamery zapełnia salę**
- [x] T12 Nagrywanie, odtwarzanie i odwrócone osoby
- [x] T13 Kadrowy z węzłami, widok z szyją
- [x] T14 Odtworzenie przesuwa Kadrowego
- [x] T15 Reżyser ciszy

## M3: Pełna misja
- [x] T16 Siedzenia, numerki, szatnia, szpule
- [x] T17 Projektor i film na ekranie
- [x] T18 Drzwi widoczne tylko w kadrze
- [x] T19 Archiwum, rejestr z nazwami graczy
- [x] T20 Kulminacja i dzwonek
- [x] T21 Wycięcie, ratunek, koniec taśmy
- [x] T22 Finałowa taśma z awatarami, raport

## M4: Hub
- [x] T23 Geometria: stanowisko, korytarz, hala, pokój taśm, ukryty pokój
- [x] T24 Intro z kamerą
- [x] T25 Drużyny: tworzenie, dołączanie, gotowość, wyrzucanie, zaproszenia
- [x] T26 Ekran przygotowania i teleport z ponawianiem
- [x] T27 Powrót do misji po rozłączeniu

## M5: Dane i UX
- [x] T28 `PlayerData` w obu miejscach, nagrody za misję
- [x] T29 Archiwum dokumentów w hubie
- [x] T30 Mobile i kontroler: przyciski, HUD
- [x] T31 Teksty PL/EN

## M6: Testy (etap 4)
- [x] T32 Solo w Studio przez MCP
- [ ] T33 Publikacja próbna (**krok właściciela**: ID miejsc, Access Control, API Services)
- [ ] T34 2 graczy, 4 graczy
- [ ] T35 Telefon rzeczywisty
- [ ] T36 Rozłączenie, błędy teleportu, restart misji, zapis

## Kryteria „działa” dla slice
1. Grupa przechodzi hub → misja → hub bez pomocy dewelopera.
2. Gracz samodzielnie odkrywa, że odtworzenie przybliża Kadrowego.
3. Misja trwa 15–25 minut przy pierwszym podejściu.
4. Stabilne 30+ FPS na telefonie średniej klasy.
5. Zapis przeżywa teleport i ponowne wejście.

## Poza zakresem do czasu testu slice
Monetyzacja, kosmetyka, kolejne misje, finalny art i audio, osiągnięcia w UI, statyw, globalna lista drużyn, analityka.
