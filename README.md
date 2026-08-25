# homebrew-legacy

Legacy Homebrew formulae and casks, pinned at specific versions.

Sibling taps: [patched](https://github.com/xooooooooox/homebrew-patched) (our fork builds) - [prebuilt](https://github.com/xooooooooox/homebrew-prebuilt) (official upstream binaries, current versions).

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

## Rebottle: keep pouring on unsupported macOS

Plain imports compile from source: `brew extract` strips the historical
`bottle do` block, and Homebrew ships no bottles for unsupported macOS
versions (monterey bottles ended 2024-09 with the Sequoia release). But
published bottles are never deleted from ghcr.io — so they can be re-hosted.

GitHub → Actions → "rebottle" → Run workflow:

- `name`: core formula name, e.g. `jq`
- `version`: optional; default = the newest version whose bottle block still
  carries the requested tag (found in homebrew-core git history)
- `bottle_tag`: default `monterey`

The workflow imports that version, downloads the official historical bottle
blob from ghcr.io, repacks the keg under this tap's formula name, uploads it
to a release named `formula-<name>@<version>`, injects a matching
`bottle do` block, verifies (`brew fetch --bottle-tag` proves the pour path
end-to-end), and opens a PR. On the target device the formula then installs
with a plain pour — no compiler, and it is the original core-built binary.

Limits:

- Versions are frozen at each formula's last bottled release for the tag
  (~2024-09 for monterey). For current versions use upstream-binary managers
  (vfox/mise) or a source-building tap with its own bottle CI instead.
- Runtime dependencies are not rewritten: they resolve to *current* core and
  would source-build on the device. The script warns loudly; rebottle each
  runtime dependency too and point `depends_on` at this tap, or stick to
  dependency-free formulas.
- Core formula names containing `@` are not supported.

The script also runs locally from the repo root (upload is CI-only):

```shell
.github/scripts/rebottle.sh jq
```
