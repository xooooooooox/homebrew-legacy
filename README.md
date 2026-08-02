# homebrew-legacy

Legacy Homebrew formulae and casks, pinned at specific versions.

Naming convention: `Casks/<app>/<app>@<version>.rb`, cask token `<app>@<version>`.

## How to use

Take installing an older version of squirrel as an example.

```shell
brew tap xooooooooox/legacy
brew install --cask xooooooooox/legacy/squirrel@1.0.3
```

## Pin

Formulae installed from this tap can be pinned so `brew upgrade` leaves them untouched:

```shell
brew pin xooooooooox/legacy/<formula>@<version>
```

Casks cannot be pinned (`brew pin` is formula-only), but a versioned cask token such as `squirrel@1.0.3` never upgrades past its version: `brew upgrade` compares the installed version against the cask file, which is fixed.

## Import a legacy version

GitHub → Actions → "import" → Run workflow:

- `type`: `cask` or `formula`
- `name`: official token / formula name, e.g. `squirrel`
- `version`: target version, e.g. `1.0.2`

The workflow digs the requested version out of the official tap's git
history (`brew extract` for formulae), applies this repo's naming
convention, verifies it (`brew style` / `brew audit` / `brew fetch`), and
opens a PR carrying the verification report. Review and merge.

The scripts also run locally from the repo root:

```shell
.github/scripts/import-cask.sh squirrel 1.0.2
```
