# urbackup-grub

Debian grub2 packages with [`patches/urbackup-grub.patch`](patches/urbackup-grub.patch) applied,
built by GitHub Actions for every supported Debian release and published as an APT
repository on GitHub Pages: <https://uroni.github.io/urbackup-grub/>

The patch makes `grub-probe`/`grub-install` follow UrBackup's device-mapper snapshot
devices (`snapshot-origin`/`era`/`linear` targets tagged `98d1f8b1f435`) to the real
root device.

## Using the repository

```sh
sudo curl -fsSL -o /usr/share/keyrings/urbackup-grub.gpg https://uroni.github.io/urbackup-grub/urbackup-grub.gpg
. /etc/os-release
sudo tee /etc/apt/sources.list.d/urbackup-grub.sources <<EOF
Types: deb
URIs: https://uroni.github.io/urbackup-grub/$VERSION_CODENAME
Suites: $VERSION_CODENAME
Components: main
Signed-By: /usr/share/keyrings/urbackup-grub.gpg
EOF
sudo apt update && sudo apt upgrade
```

## How it works

- `.github/workflows/build.yml` runs on push, daily, and manually. For each release in the
  matrix it fetches the current Debian `grub2` source (including `-updates`/`-security`),
  adds the patch to the quilt series, and builds it as `<debian-version>+urbackup<REVISION>`.
- A build is skipped when that version is already published, so a new Debian grub2 update
  triggers an automatic rebuild. **After changing the patch, bump `REVISION`** (or run the
  workflow manually with `force`).
- Debian's `grub-efi-amd64-signed` pins an exact `grub-common` version, so it is repackaged
  with a matching version and dependency. The Secure Boot signed EFI images inside are
  unchanged (the patch only touches userland tools).
- `-dbg` packages are left out to stay within the GitHub Pages size limits.
- The repository state lives in the `gh-pages` branch as a single force-pushed commit and is
  deployed via `actions/deploy-pages`. Each release is a separate repository under `/<codename>/`.
- Indexes are signed with the key in the `REPO_SIGNING_KEY` secret (created once with
  `scripts/create-signing-key.sh`; keep the backup, rotating the key breaks existing clients).

To add a Debian release, add it to the `matrix.release` list in the workflow.
