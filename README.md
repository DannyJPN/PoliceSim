# PoliceSim

Realistický policejní simulátor v otevřeném světě, postavený na Godot 4 (GDScript).
_Realistic open-world police simulator, built on Godot 4 (GDScript)._

## Struktura projektu / Project structure

```
data/laws/          Zákony jednotlivých zemí (JSON) + JSON schema
                     Per-country law data (JSON) + JSON schema
src/systems/         Herní systémy (Law Engine, ...)
                     Core game systems (Law Engine, ...)
tests/               Testy a jednoduchý headless test runner
                     Tests and a lightweight headless test runner
```

## Law Engine

`src/systems/law_engine.gd` načítá zákony aktivní země z `data/laws/{COUNTRY}.json`
(validováno proti `data/laws/schema.json`) a poskytuje API pro:

- filtrování přestupků dle zóny a doby dne,
- filtrování/skládání sankcí dle přestupku a trestního rejstříku NPC,
- výpočet rozpětí pokuty včetně recidivního multiplikátoru,
- určení, zda je varování povoleno,
- určení, zda je uvěznění možné.

`data/laws/CZ.json` obsahuje přestupky pro Českou republiku pokrývající všechny
herní zóny (`city_center`, `residential`, `industrial`, `road`, `rural`).

## Spuštění testů / Running tests

Testy jsou napsané jako čisté GDScript soubory (`tests/test_*.gd`), spouštěné
headless přes Godot engine, bez závislosti na herní scéně:

```sh
godot --headless --script res://tests/test_runner.gd
```

Návratový kód je `0`, pokud všechny testy prošly, jinak `1`.
