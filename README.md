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
