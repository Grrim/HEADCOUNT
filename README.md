# HEADCOUNT

Kooperacyjny horror na Roblox (1–4 graczy). Kamera pokazuje to, czego nie widzi oko, a każde odtworzenie nagrania przybliża to, co jest na taśmie.

- Koncepcja i projekt: [docs/02_GDD.md](docs/02_GDD.md)
- Architektura: [docs/03_TDD.md](docs/03_TDD.md)
- Aktualny stan, testy i znane problemy: [docs/05_STATUS.md](docs/05_STATUS.md)
- Plan rozwoju: [docs/07_ROADMAP.md](docs/07_ROADMAP.md)
- Punkt wznowienia pracy: [PROGRESS.md](PROGRESS.md)

## Praca z projektem

Narzędzia są przypięte w `rokit.toml`:

```bash
rokit install
```

Bramki jakości (budowa obu miejsc, testy logiki, lint, formatowanie):

```bash
python scripts/check.py
```

Wynik trafia do `build/Hub.rbxl` i `build/Mission.rbxl`. Otwórz je w Studio i uruchom Play. Źródłem prawdy jest dysk, więc **nie edytuj skryptów w Studio**.

## Sterowanie

| Akcja | PC | Kontroler |
|---|---|---|
| Interakcja | E | X |
| Kamera | PPM lub Q | L2 |
| Nagraj | R | R2 |
| Odtwórz ostatnią taśmę | T | Y |
| Latarka | F | D-pad góra |
| Komunikaty radiowe | 1–4 | D-pad lewo/prawo/dół, B |
| Pukanie (poza kadrem) | K | X |

Na urządzeniach dotykowych te same akcje są pod przyciskami ekranowymi.

W Studio serwer misji wypisuje w Output rozwiązanie zagadki. Na żywym serwerze ten kod się nie wykonuje.

## Publikacja (kroki właściciela)

1. Opublikuj `build/Hub.rbxl` jako Start Place nowego doświadczenia.
2. Dodaj drugie miejsce w tym doświadczeniu i opublikuj do niego `build/Mission.rbxl`.
3. Wpisz oba ID do `src/shared/Config/Places.luau`, przebuduj i opublikuj oba miejsca ponownie.
4. W Creator Hub ustaw dla misji Access Control na **Secure within universe only**.
5. W Game Settings włącz dostęp do API (Enable Studio Access to API Services) do testów DataStore.
6. Wypełnij kwestionariusz Maturity & Compliance. Cel to Mild.
