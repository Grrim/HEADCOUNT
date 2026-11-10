# 06. Assety

Stan na 2026-11-07. **Wszystko poniżej jest tymczasowe.** Modele i materiały pochodzą z generatorów Roblox Studio i należą do konta właściciela. Odbiorcy tego stylu cenią ręczną robotę (patrz `00_RESEARCH.md`), więc przed premierą modele bohaterów, ikonę i miniatury trzeba zrobić ręcznie.

## Modele (`src/shared/Models`)

| Plik | Użycie | Do wymiany przed premierą |
|---|---|---|
| `Registrar` | Kadrowy | **Tak, najpierw** |
| `Sitter`, `SitterBrown`, `SitterNavy` | Widownia | **Tak** |
| `Chair` | Krzesła | Tak |
| `Desk`, `Bell`, `Projector`, `Recorder` | Rekwizyty fabularne | Tak |
| `Crt`, `Bench`, `Coat`, `Shelf`, `Boiler`, `DeskLamp`, `CoffeeMachine`, `Boxes` | Wystrój | Jeśli się opłaci |

Wszystkie trzy modele widowni korzystają z tej samej siatki (2 studs wysokości), więc kalibracja w `Props.sitter` obowiązuje każdy z nich. Tekstura `MeshPart` ignoruje `Color`, dlatego zbyt jasny model trzeba przeteksturować. Sam `Color` w plikach to ciemny kolor zapasowy na czas ładowania.

Sylwetka Kadrowego w modelu nie ma głowy, bo głowy nigdy nie widać. Docelowy model musi mieć własny charakter i nie może przypominać garnituru bez głowy z referencji `piscode_`. Nasz wyróżnik to szyja rosnąca poza kadr.

## Materiały (`src/materials`)

`PK_Carpet`, `PK_Wallpaper`, `PK_CeilingTile`, `PK_Veneer`, `PK_Terrazzo`. Przydziela je `World/Surfaces.luau` według koloru części, więc wymiana materiału nie wymaga zmian w kodzie poziomów.

Generator utworzył po kilka wersji każdego materiału. Użyte są pierwsze; pozostałe nie trafiły do projektu.

## Dźwięki

Tymczasowe ID z Creator Store są w `src/shared/Config/Sounds.luau`.

## Jak dodać model

Skrypt nie może ustawić `MeshId`, więc model musi być plikiem `.rbxmx` w `src/shared/Models` z polami `MeshId`, `TextureID`, `InitialSize` i `size`. Stawia go `Props.place`.

**`InitialSize` musi być prawdziwym rozmiarem siatki.** Wartość zmierz przez `AssetService:CreateMeshPartAsync`, bo po przeteksturowaniu generator potrafi zwrócić siatkę o innych wymiarach. Błędna wartość cicho przeskaluje model i przesunie go względem podłogi.

## Specyfikacje do zewnętrznej produkcji (2026-11-10)

Tych assetów nie dało się zrobić w tym środowisku. Gra działa bez nich na obecnych zamiennikach. Kolejność to kolejność wpływu na odbiór.

### 1. Kadrowy (`Registrar.rbxmx`) — najważniejszy

- **Sylwetka:** wyższy od drzwi (ok. 9–10 studów do barków), wąskie, opadające barki, za długie ramiona (dłonie poniżej kolan), garnitur urzędnika z lat 70. o zbyt luźnym kroju. Z daleka ma się czytać jako „urzędnik”, z bliska jako „coś udaje urzędnika”.
- **Głowa:** poza kadrem, zawsze. Kod rysuje szyję rosnącą w sufit (`RegistrarView.luau`), więc model kończy się kołnierzem ze sztywną, zbyt długą szyją (ok. 1,5 studa), z której wychodzi szyja proceduralna.
- **Ręka do sięgania:** osobna siatka przedramienia i dłoni z czterema palcami (kod ją wysuwa i zaciska palce). Punkt obrotu w barku.
- **Materiał:** matowy, zgaszony szary garnitur, papierowa biel mankietów i kołnierza, żadnego połysku. Tekstura max 1024², jedna.
- **Budżet:** do 4 000 trójkątów, jedna siatka + ręka. Bez kości: kod porusza go klatkami (poklatkowo), więc szkielet nie jest potrzebny.
- **Odróżnienie od referencji:** nie może przypominać garnituru bez głowy z `piscode_` (patrz wyżej). Wyróżnik to szyja i nieludzkie proporcje.

### 2. Widownia (`Sitter*.rbxmx`)

- Postać siedząca, dorosłe proporcje (obecne siatki są klockowate i czytają się jak awatary Roblox). Pięć wariantów ubrań z lat 70.–80. (garnitur brązowy, granatowy, szary, sweter, płaszcz) na jednej siatce bazowej.
- Twarz: gładka, bez rysów, z czarnym paskiem na oczach (to już jest motyw gry).
- **Budżet:** 192 sztuki naraz w kadrze, więc do 800 trójkątów na postać i jedna wspólna tekstura 512². Wymiary jak obecne (kalibracja w `Props.sitter`).

### 3. Krzesło, biurko, dzwonek, projektor, magnetofon

Krzesło składane z lat 70. (sklejka i rurka), 192 sztuki: do 300 trójkątów. Pozostałe rekwizyty fabularne: do 2 000 trójkątów, jedna tekstura 512², proporcje jak obecne zamienniki.

### 4. Dźwięki (do nagrania lub zakupu, wgranie przez właściciela)

Obecne ID z Creator Store są tymczasowe i dobrane po nazwie i długości; nikt ich nie oceniał uchem. Brakuje lub wymaga wymiany:

| Nazwa w `Sounds.luau` | Potrzeba | Długość |
|---|---|---|
| `LensUp` (osobno: podniesienie / opuszczenie) | Mechaniczny klik i szum wizjera kamery VHS | 0,3–0,6 s |
| `RecStart` (osobno: start / stop nagrania) | Klawisz magnetowidu, przy stopie niższy | 0,2–0,4 s |
| nowy `UiClick` | Bardzo cichy klik przycisku interfejsu (dziś `RecStart` z wyższą wysokością) | 0,1 s |
| nowy `Punch` | Podwójny klik kasownika biletów (dziś `RecStart` nisko) | 0,3 s |
| `Heartbeat` | Prawdziwe bicie serca (dziś obniżony `Reach`) | pętla 1–2 s |
| `Cut` | Dźwięk cięcia taśmy: szarpnięcie, szum, cisza | 1–1,5 s |
| nowy `Steps` (dywan, beton, metal) | Kroki gracza i Biletera, po 4 warianty na podłoże | 0,3 s |
| `Ambient`, `Hum` | Szum sali i transformatora, bez widocznej pętli | 60 s+ |
| `Projector` | Projektor 16 mm, pętla | 10 s+ |
| nowy `Silence` | Wsysanie powietrza przed ciszą Kadrowego | 1,5 s |

Głośności i wysokości są w wywołaniach `AudioDirector.play`, więc wymiana pliku nie wymaga zmian w kodzie poza ID.

### 5. Interfejs

Kroje są wbudowane w Roblox (Oswald, Builder Sans, Roboto Mono, Special Elite), więc niczego nie trzeba wgrywać. Ikony są rysowane z ramek. Do premiery: ikona gry i miniatury (to już było w planie).
