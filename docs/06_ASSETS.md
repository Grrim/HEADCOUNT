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
