# Source Provision Flow

- Version: 0.2.0 (draft)
- Last updated: 2026-11-13
- Related: [`license.md`](license.md), [`requirements.md`](requirements.md), [`../iso/COPYING`](../iso/COPYING)

## 1. Purpose

The SabakanOS ISO image contains binaries covered by the GPL and LGPL. This document defines how the complete corresponding source, or the route to obtain it, is prepared for every binary in the distribution, and how that is verified, published and retained for each release.

There is exactly one goal:

> At the moment of release, a third party who receives the ISO must be able to rebuild the same binary from the same source for every OSS component in that ISO.

## 2. Principles

1. **One binary, one source** — every binary in the ISO has one row in the manifest.
2. **Pin the version** — identify it by a tag, a commit hash or a tarball hash. "Latest" is not an acceptable value.
3. **One of three provision routes** — the source travels on the same medium, is downloadable from the same server, or is offered in writing.
4. **Do not hide modifications** — patches, configuration changes and font subsetting are all recorded and included in the bundle.
5. **Keep the records for three years** — the source stays obtainable for three years after distribution ends.

## 3. Terms

| Term | Definition |
|------|------------|
| Corresponding Source | The complete source used to produce a binary, including build scripts, configuration, patches and the generation steps |
| Manifest | The list that maps each binary to its source, license and retrieval location (`docs/source-manifest.tsv`) |
| Source bundle | The source tree collected by `scripts/collect-sources.sh` (`build/sources/`) and its archive |
| SBOM | A machine-readable list of the bundled components (SPDX or CycloneDX) |
| Written offer | A document offering the source in writing, permitted by GPL-2.0 section 3(b) and equivalent clauses |

## 4. Overall Flow

```text
[1] Component adoption
      |  an implementation lane adds it to packages/
      v
[2] License identification and manifest entry     <- update the tables in docs/license.md
      |
      v
[3] Source retrieval (pinned version, recorded hash)
      |  scripts/collect-sources.sh
      v
[4] Recording modifications (patches and configuration)
      |
      v
[5] Consistency verification (binaries in the ISO <-> manifest <-> source)
      |  CI: license-check workflow
      v
[6] Release (ISO + source bundle + SBOM attached together)
      |
      v
[7] Retention and audit (three years, hashes and retrieval log kept)
```

## 5. Manifest Specification

`docs/source-manifest.tsv` is tab-separated UTF-8 text. One row is one component. The template is [`source-manifest.example.tsv`](source-manifest.example.tsv); copy it to `docs/source-manifest.tsv` and fill in the real values.

### 5.1 Columns

| Column | Required | Content | Example |
|--------|----------|---------|---------|
| `component` | yes | Package name. Must match `/usr/share/licenses/<component>/` | `busybox` |
| `version` | yes | Pinned version: a tag name or a commit hash | `1.37.0` |
| `license` | yes | SPDX identifier. Combine with `AND` / `OR` | `GPL-2.0-only` |
| `upstream_url` | yes | URL of the upstream project | `https://busybox.net` |
| `source_url` | yes | Where the corresponding source is retrieved (tarball or repository) | `https://busybox.net/downloads/busybox-1.37.0.tar.bz2` |
| `sha256` | yes | SHA-256 of the retrieved source archive. May be empty when the source is taken from a repository checkout | `4f2c...` |
| `patches` | no | File names of applied patches (under `patches/<component>/`). Separate several with commas | `0001-jp106-keymap.patch` |
| `in_iso` | yes | Whether the component is bundled in the ISO (`yes` / `no`). `no` means a build-host-only tool | `yes` |
| `notes` | no | Free-form remarks, for example the state of a license review | `includes dictionary data` |

### 5.2 Example

| component | version | license | source (summary) | in_iso |
|-----------|---------|---------|------------|--------|
| linux-kernel | 6.18.63 | GPL-2.0-only | the matching tarball from kernel.org | yes |
| busybox | 1.37.0 | GPL-2.0-only | the tarball from busybox.net | yes |
| musl | 1.2.5 | MIT | the tarball from musl-libc.org | yes |
| openrc | 0.56 | BSD-2-Clause | the tag from github.com/OpenRC/openrc | yes |
| apk-tools | 2.14.4 | GPL-2.0-only | the tag from gitlab.alpinelinux.org/alpine/apk-tools | yes |
| alpine-baselayout | 3.7.2 | GPL-2.0-only | the aports archive | yes |
| limine | 8.x | BSD-2-Clause | the release from github.com/limine-bootloader/limine | yes |
| buildroot | 2026.08.1 | GPL-2.0-or-later | the tarball from buildroot.org | no |
| xorriso | 1.5.x | GPL-3.0-or-later | the tarball from gnu.org | no |

> The real values are fixed for each release. Tools with `in_iso=no` (build host only) create no source obligation because they are not in the ISO, but they stay in the manifest for reproducibility.

### 5.3 Validation Rules

The manifest is machine-checked by `.github/workflows/license-check.yml`. A row is rejected when:

- it does not have exactly nine columns, or the header does not match the specification above
- `component`, `version`, `license`, `upstream_url`, `source_url` or `in_iso` is empty
- `version` is `latest`, `master`, `main`, `HEAD` or `TBD`
- `license` is not an SPDX expression such as `GPL-2.0-only` or `MIT AND BSD-3-Clause`
- a URL is not `https://`
- `in_iso` is neither `yes` nor `no`
- a row whose `source_url` is an archive (`*.tar.*`, `*.tgz`, `*.zip`) has no `sha256`, or the hash is not 64 lowercase hexadecimal characters
- a bundled component (`in_iso=yes`) is missing from `iso/COPYING` or from `docs/license.md`
- a file named in `patches` does not exist at that path or under `patches/<component>/`

On a pull request, a missing hash is reported as a warning because the hash is normally recorded when the version is cut. On a release tag it is an error and blocks the release.

## 6. Source Collection Procedure

### 6.1 Pin the Version

1. Fix the upstream release tag or commit hash and record it in `version`.
2. Retrieve the tarball and record `sha256sum` in `sha256`.
3. Verify the OpenPGP signature when upstream publishes one.

```bash
# Example: retrieve and verify
curl -LO https://busybox.net/downloads/busybox-1.37.0.tar.bz2
sha256sum busybox-1.37.0.tar.bz2
# When a signature is published
gpg --verify busybox-1.37.0.tar.bz2.sig busybox-1.37.0.tar.bz2
```

### 6.2 Record the Modifications

- Keep kernel configuration (`.config`), build variables and `defconfig` changes in `config/`, and include them in the bundle unchanged.
- Keep patches in `patches/<component>/` and list them in the `patches` column.
- Number patches in application order and add a `series` file when the order matters.
- When a font was subset, include both the generation script and the original font.

### 6.3 Run the Collection Script

```bash
./scripts/collect-sources.sh
```

The script takes no options. It reads its input from the repository:

| Input | Used for |
|-------|----------|
| `config/packages.txt` | The package names to collect (first field of each non-comment line) |
| the pinned package table inside the script | Version, license, source URL and archive name for each GPL/LGPL package, plus the kernel |
| `config/kernel-defconfig`, `config/buildroot-defconfig` | Copied into the bundle as the build configuration |
| `patches/<component>/*.patch` | Applied in file-name order with `patch -p1` when the directory exists |

What the script does:

1. Select the targets: every table entry whose package appears in `config/packages.txt`, plus `linux-kernel`.
2. Download each source archive into `build/sources/<component>/`, reusing a file that is already there.
3. Compute the SHA-256 of the archive twice, compare the two results and record the value.
4. Extract the archive in place and locate the top-level source directory.
5. Apply the patches of `patches/<component>/` and record the names of the patches that applied.
6. Copy the kernel and Buildroot configurations into `build/sources/config/`.
7. Write `build/source-manifest.json`.

| Output | Content |
|--------|---------|
| `build/sources/<component>/` | The archive and its extracted source tree |
| `build/sources/config/` | `kernel-defconfig` and `buildroot-defconfig` |
| `build/source-manifest.json` | `generated_at`, `project`, and `components[]` with `name`, `version`, `license`, `source_url`, `archive`, `archive_path`, `sha256`, `status`, `source_dir`, `patches` |

Each component carries a `status` of `collected`, `download_failed`, `hash_mismatch` or `extract_failed`. The script records a failure and continues with the next component, so the release owner must check that **every component reports `collected`** before going further. A non-zero count of any other status blocks the release.

The package table lives inside the script. Keep it in step with `docs/source-manifest.tsv`: a component with `in_iso=yes` in the manifest must exist in both, with the same version and license. Section 13 lists the planned change to read the manifest directly.

### 6.4 Bundle Layout

```text
build/
├── source-manifest.json          # Collection manifest written by collect-sources.sh
├── SOURCE-MANIFEST.json          # Source correspondence table (see 7.3)
├── SBOM.spdx.json                # SPDX 2.2 SBOM (see 7.2)
└── sources/
    ├── config/
    │   ├── kernel-defconfig
    │   └── buildroot-defconfig
    ├── linux-kernel/
    │   ├── linux-6.18.63.tar.xz
    │   └── linux-6.18.63/
    ├── busybox/
    │   ├── busybox-1.37.0.tar.bz2
    │   └── busybox-1.37.0/
    └── ...
```

The bundle that is published is the archive of `build/sources/` together with the three JSON files:

```bash
tar -C build/sources -cf - . | zstd -19 -T0 -o build/sabakanos-<version>-source.tar.zst
```

### 6.5 Contents of README.txt

`README.txt` is written by the release owner and placed next to the archive in the Release. It states:

- the SabakanOS version and the matching Git tag
- where each source came from and how to verify it (the SHA-256 values in `SOURCE-MANIFEST.json`)
- the build steps (`make build-kernel` and so on) and the toolchain version
- the contact address

## 7. SBOM and SOURCE-MANIFEST Generation

### 7.1 Run the SBOM Script

```bash
./scripts/generate-sbom.sh
```

The script takes no options and needs `jq`. It reads `build/source-manifest.json`, so `scripts/collect-sources.sh` must have run first; without that file it exits non-zero.

What the script does:

1. Validate `build/source-manifest.json` as JSON.
2. Build the SPDX document header: `spdxVersion`, `name`, `documentNamespace`, `creationInfo` with the creation time and the tool name.
3. Convert every component into an SPDX package: `name`, `version`, `licenseDeclared`, `downloadLocation`, a SHA256 `checksum` and the `files` entry.
4. Write `build/SOURCE-MANIFEST.json`.
5. Validate both outputs as JSON and print the package count.

| Output | Content |
|--------|---------|
| `build/SBOM.spdx.json` | SPDX 2.2 document listing every collected component |
| `build/SOURCE-MANIFEST.json` | One entry per component: `component`, `version`, `license`, `upstream_url`, `source_url`, `sha256`, `local_path`, `status` |

### 7.2 SBOM.spdx.json

The SBOM is the machine-readable component list of the release. It is attached to the GitHub Release next to the ISO and the source bundle, and it is the file a redistributor or an auditor reads first.

- The format is SPDX 2.2 JSON. Each package carries the name, the version, the declared license, the download location, the SHA-256 checksum and the path of the source inside the bundle.
- The SBOM covers every component that the collection script processed, which is every GPL/LGPL package in `config/packages.txt` plus the kernel.
- Build-host-only tools are not collected and therefore do not appear; the manifest keeps them for reproducibility.

### 7.3 SOURCE-MANIFEST.json

`SOURCE-MANIFEST.json` is the source correspondence table of one release: it says, for each component, which version was collected, where it came from, what its hash is and where it sits in the bundle.

| Key | Content |
|-----|---------|
| `component` | Component name, matching `build/sources/<component>/` |
| `version` | The pinned version that was collected |
| `license` | SPDX identifier taken from the collection table |
| `upstream_url` | The source URL used for the download |
| `source_url` | The same URL, kept for consumers that expect a single field |
| `sha256` | SHA-256 of the collected archive |
| `local_path` | Path of the archive inside the bundle |
| `status` | The collection status (`collected` when the collection succeeded) |

There are three manifest files in a release, and they serve different purposes:

| File | Role | Written by |
|------|------|------------|
| `docs/source-manifest.tsv` | Declaration: what the release intends to ship, with the nine columns of section 5.1 | A human, before the release |
| `build/source-manifest.json` | Collection result: what was downloaded, hashed and extracted | `scripts/collect-sources.sh` |
| `build/SOURCE-MANIFEST.json` | Published correspondence table: the subset of the collection result that ships with the release | `scripts/generate-sbom.sh` |

An audit compares the declaration with the collection result. A component that is declared with `in_iso=yes` but missing from the collection result is a release blocker.

### 7.4 What Must Agree

Before a release, these four lists must be identical:

1. the binaries in the ISO
2. the components in `iso/COPYING`
3. the rows with `in_iso=yes` in `docs/source-manifest.tsv`
4. the components in `build/SOURCE-MANIFEST.json`

The workflow checks 2 and 3, and that the collection and SBOM outputs exist. Item 1 is checked by hand, because the workflow sees the repository, not the produced image.

## 8. Distribution Methods

The routes are listed in priority order.

### 8.1 Download From the Same Server (Default)

The ISO and the source bundle are attached to the same GitHub Release. Because both are reachable from the same release page, the route satisfies GPL-3.0 section 6(d) and, for the GPL-2.0 components, the source accompanies the download as required by GPL-2.0 section 3(a).

```text
https://github.com/ryopc/sabakan-os/releases/tag/v<version>
├── sabakanos-<version>-x86_64.iso
├── sabakanos-<version>-x86_64.iso.sha256
├── sabakanos-<version>-source.tar.zst
├── SOURCE-MANIFEST.json
├── SBOM.spdx.json
├── COPYING
└── SHA256SUMS
```

### 8.2 Same Medium

When the source is small enough to fit, it can be shipped on the ISO or on an accompanying volume. This satisfies GPL-2.0 section 3(a) and GPL-3.0 section 6(a) directly. It affects the ISO size target ([`requirements.md`](requirements.md) NFR-003), so 8.1 is the default.

### 8.3 Written Offer

Only when the routes above are impractical (offline distribution, redistribution by a third party) is a written offer issued. The validity period is three years from the date of distribution.

```text
Written Offer for Source Code

For the GPL and LGPL covered software contained in SabakanOS <version>
(distributed on <YYYY-MM-DD>), we offer any third party a complete
machine-readable copy of the corresponding source code.

Components: <the component list in iso/COPYING>
How it is provided: electronic download (a URL is sent on request) or
physical media
Validity of this offer: three years from the date of distribution
Charge: no more than the cost of physically performing source distribution
Contact: <project contact>

This offer is made under GPL-2.0 section 3(b), GPL-3.0 section 6(b) and
LGPL-2.1 section 6.
```

The offer only satisfies the clause it names when all of the following hold, and the release owner confirms each one:

1. it is addressed to any third party, not only to the direct recipient
2. it stays valid for at least three years from the date of distribution
3. the charge does not exceed the cost of physically performing source distribution
4. what is offered is the complete machine-readable source, including build configuration and patches
5. it names the version and the components covered

An issued written offer is kept with the distribution log for three years, because the obligation outlives the release. A written offer does not replace shipping the full license texts.

## 9. Release Procedure

1. Confirm that CI on `main` is green.
2. Finalise the declaration: update `docs/source-manifest.tsv` with the versions, URLs and hashes for this release.
3. Update `iso/COPYING` and reconcile it with `/usr/share/licenses/` in the ISO.
4. Run `./scripts/collect-sources.sh` and confirm that every component in `build/source-manifest.json` reports `status: collected`.
5. Run `./scripts/generate-sbom.sh` and confirm that `build/SBOM.spdx.json` and `build/SOURCE-MANIFEST.json` are written.
6. Archive the bundle as `sabakanos-<version>-source.tar.zst` and write `README.txt` (section 6.5).
7. Build the ISO and record `sha256sum` of the image.
8. Confirm that the license check passes on the release tag (release mode, no findings).
9. Push the tag and let `.github/workflows/release.yml` create the Release.
10. Confirm that the Release carries the ISO, the ISO hash, the source bundle, `SOURCE-MANIFEST.json`, `SBOM.spdx.json`, `COPYING` and `SHA256SUMS`.
11. Work through the pre-release checklist in [`license.md`](license.md) section 11 and record the result.
12. Store the artifacts in the retention location (the Release and the backup).

## 10. CI Verification

Two workflows verify this process.

`.github/workflows/ci.yml` runs on every push and pull request and checks the static facts:

| Check | Job | Fails when |
|-------|-----|------------|
| Required files exist | `docs` | `iso/COPYING`, `docs/license.md`, `docs/source-flow.md` or the manifest template is missing |
| `iso/COPYING` content | `license` | A component, a license family or the `/usr/share/licenses/` pointer is missing |
| Manifest format | `license` | The header does not match the nine-column specification |
| Secret patterns | `license` | A string such as `BEGIN PRIVATE KEY` is found, or a secret file is tracked |

`.github/workflows/license-check.yml` is the release gate. It runs on pull requests and on `v*.*.*` tags and checks that:

| Check | Fails when |
|-------|------------|
| Package inventory | `config/packages.txt` is missing, empty, or contains a package with no license mapping |
| License records | A package has no row in `docs/license.md` or `iso/COPYING`, or the row states no license identifier |
| Source records | The manifest is missing on a tag, the header or column count is wrong, a version is not pinned, a license is not SPDX, or a URL is not https |
| Hashes and patches | An archive has no `sha256` (on a tag), a hash is malformed, or a referenced patch is missing |
| COPYING notices | A notice, license family, license directory pointer or the source provision section is missing |
| Documentation statements | The clause numbers or the tooling names are not stated, or the documents contain non-English text |
| Source tooling | `scripts/collect-sources.sh` or `scripts/generate-sbom.sh` is missing (on a tag), not executable, or syntactically broken |
| Source outputs | `build/source-manifest.json` is present but invalid, lists no components, or a component reports a status other than `collected` |

A single finding fails the run, so the release stops before publishing. The step summary lists every finding with the file it came from.

## 11. Retention and Audit

| Item | Retention | Location |
|------|-----------|----------|
| ISO and its hash | three years or more | GitHub Release (never deleted) plus a local backup |
| Source bundle | three years or more | as above |
| `SOURCE-MANIFEST.json`, `SBOM.spdx.json` and `source-manifest.json` | three years or more | as above |
| Pre-release checklist record | three years or more | `docs/releases/<version>.md` (to be added) |
| Issued written offer | three years or more | recorded with the release log |

An audit walks the chain "binary in the ISO -> `iso/COPYING` -> manifest -> source bundle" and confirms that each step matches the next.

## 12. Incident Response

| Situation | Action |
|-----------|--------|
| Upstream source disappeared | Provide the retained source bundle. Publish a mirror when redistribution is permitted |
| Hash mismatch | Stop the release. Assume the source was altered or compromised, retrieve it from another mirror and compare |
| A license changed mid-flight | Check the terms of the version in use, re-pin if needed, and update `license.md` |
| A bundled component turns out to have an unknown license | Remove it from the ISO, or stop the release until permission is confirmed |
| Secrets were distributed by mistake | Revoke the affected key immediately, withdraw the release and record the scope |

## 13. Planned Automation

Planned additions to CI and to the scripts:

- let `scripts/collect-sources.sh` read `docs/source-manifest.tsv` directly, so the declaration and the collection cannot drift apart (today the pinned table lives inside the script)
- make a failed download or a failed extraction a hard failure instead of a recorded status
- detect manifest rows that are missing for packages found in `packages/`
- enumerate the ELF files in the ISO and diff them against the manifest
- generate the SPDX SBOM with `syft` or `cyclonedx` as an independent cross-check
- rebuild the source bundle and compare hashes (reproducibility check)
