# 11. Prototyp zmiany: jak go uruchomić i co sprawdzić

Stan na 2026-11-19. Prototyp Etapu 0 z `09_GDD_V2.md` §12, na gałęzi `prototype-shift`. Misja 001 i lobby są nietknięte.

## 1. Co jest w prototypie

- **Osobne, trzecie miejsce: Shift** (`shift.project.json` → `build/Shift.rbxl`). Działa samo, bez teleportu.
- **Winda:** stoi w miejscu, a za zamkniętymi drzwiami powstaje kolejne piętro.
  - Tabliczka nad drzwiami pokazuje piętro i liczbę osób w kabinie.
  - Przyciski na bocznej ścianie, przy drzwiach: **DOWN** (czerwony, niżej) i **UP** (zielony, wyżej). Oba wymagają, żeby cała drużyna była w kabinie.
  - Drzwi zamykają się przez 4 s, ale stoją, gdy Kadrowy jest w pomieszczeniu przed windą, a nikt go nie filmuje.
- **Zjazd:** około 12 s, z jednym losowym zdarzeniem (mrugające światło, kroki na dachu albo wskaźnik pokazujący −13). Na końcu dzwonek.
- **Piętra −1 do −5:** losowo złożone z pomieszczeń (sala z krzesłami, biuro, magazyn, szatnia, korytarz z kotarami), z pętlami. Każde piętro niżej jest ciemniejsze i ma inny kolor. Od −4 meble wiszą pod sufitem.
- **Anomalie widać tylko w kamerze:**
  - zwykła: ktoś siedzi na krześle,
  - rzadka: ktoś stoi bez ruchu,
  - epicka: siedzi i obraca się w stronę obiektywu.
- **Nagrania:** serwer ocenia każde od jednej do pięciu gwiazdek: trzymaj anomalię w kadrze co najmniej 1 s, dłużej niż 2,5 s, bliżej niż 25 i 12 studs, i choć raz w samym środku. Drużyna dostaje zapłatę za najlepsze ujęcie każdej anomalii, więc filmowanie tej samej drugi raz daje tylko różnicę.
- **Norma:** 40 punktów solo, +20 za każdą osobę więcej. Nagrania liczą się do normy dopiero po odjeździe windą z piętra. Mnożniki pięter: ×1, ×1,5, ×2, ×3, ×4.
- **Kadrowy:** te same reguły co w Misji 001. Budzi się 25 s po otwarciu drzwi na −1 (12 s na głębszych piętrach), z każdym piętrem jest szybszy, a solo wolniejszy.
- **Wycięcie z kadru:** kolega przywraca cię, filmując cię przez 3 s. Solo raz na zmianę możesz po 30 s sam wrócić do windy. Gdy wszyscy są wycięci i nie ma powrotu, zmiana przepada i Biuro płaci 25% tego, co było już w windzie.
- **Kamera:** bateria (30 s, ładuje się przy opuszczonej kamerze, w windzie trzy razy szybciej), z podniesioną kamerą idziesz wolniej, kasety odnawiają się w windzie.
- **Wypłata i ulepszenia:** po zmianie ekran z wynikiem, Klatkami i dwoma ulepszeniami (bateria, kasety), potem **NEXT SHIFT**.

**Czego jeszcze nie ma (zgodnie z planem):** Statysty, odtwarzania taśm, drzwi z kodem, Biletera, zapisu postępów (pieniądze i ulepszenia znikają po zamknięciu serwera), dźwięków i grafiki docelowej, wind „dołącz do ekipy”.

## 2. Jak uruchomić (bez instalowania czegokolwiek)

1. Otwórz https://github.com/Grrim/HEADCOUNT/actions i wybierz najnowszy przebieg „check” na gałęzi **prototype-shift**.
2. Na dole, w **Artifacts**, pobierz **places** i rozpakuj.
3. Otwórz **`Shift.rbxl`** w Roblox Studio i naciśnij **Play**.
4. Pojawiasz się w windzie. Podejdź do czerwonego przycisku na bocznej ścianie przy drzwiach i przytrzymaj **E** (DOWN).

**Sterowanie:** Q albo prawy przycisk myszy podnosi kamerę, R nagrywa, F włącza latarkę, E obsługuje przyciski windy.

**Test w kilka osób w Studio:** zakładka Test → Clients and Servers, 2–4 graczy.

**Atrybut pomocniczy w Workspace:** `DevPauseRegistrar` (boolean) = true usypia Kadrowego, żeby spokojnie obejrzeć piętra.

## 3. Co sprawdzić (lista dla testu)

**Najpierw, czy w ogóle działa:**
- [ ] Gra startuje bez czerwonych błędów w Output (szukaj `[Loader]`).
- [ ] DOWN zamyka drzwi, winda „jedzie”, drzwi otwierają się na piętro −1.
- [ ] Przez kamerę widać postacie w pokojach, a gołym okiem ich nie ma.
- [ ] Nagranie postaci daje gwiazdki i punkty w lewym górnym rogu.
- [ ] Kadrowy budzi się, zatrzymuje w kadrze i wycina po dotyku.
- [ ] UP kończy zmianę i pokazuje ekran wypłaty, na którym da się kliknąć przyciski.
- [ ] NEXT SHIFT zaczyna nową zmianę.

**Potem, czy jest fajne** (progi z GDD §12):
- [ ] Czy po zmianie testerzy sami chcą zagrać kolejną? (cel: co najmniej 60%)
- [ ] Czy po pierwszej zmianie rozumieją, że Kadrowy rusza się tylko poza kadrem? (cel: co najmniej 70%)
- [ ] Czy przynajmniej w połowie zmian ktoś wybiera „w dół”? (to znaczy, że decyzja przy windzie działa)
- [ ] Ile trwa zmiana? (cel: 8–15 minut)

**Do strojenia** (wszystko w `src/shared/Config/Game.luau`, sekcja `Shift`): czas snu Kadrowego, przyspieszenie na piętro, bateria, wartości anomalii. Norma i mnożniki są w `src/shared/Core/Shift.luau`.

## 4. Czego nie sprawdzono

Prototyp przechodzi bramki jakości na GitHubie: budowa trzech miejsc, 81 testów logiki (16 nowych: generator pięter, przebieg zmiany, ocena nagrań, ulepszenia), selene i stylua. **Nigdy jednak nie działał w Studio.** Pierwsze uruchomienie na pewno pokaże rzeczy do poprawy: kadr, rozmiary pokoi, chód, kolizje mebli z anomaliami, czytelność HUD. Wklej błędy z Output albo zrzut ekranu, a poprawię.
