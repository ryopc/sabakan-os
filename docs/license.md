# License Compliance Policy

- Version: 0.2.0 (draft)
- Last updated: 2026-11-13
- Scope: the SabakanOS repository, build artifacts, distributed ISO images and source bundles

## 1. Purpose

SabakanOS is assembled from a large number of open source components. This document sets out the policy for knowing the license of every bundled component and for reliably fulfilling the obligations that apply when distributing them.

The intended audience is:

- implementers who add packages or components
- the people who perform releases
- reviewers who check the licensing of what is shipped

## 2. Principles

1. **Record everything that is bundled** — when you add a single binary, update `iso/COPYING`, the inventory in this document, and the source manifest at the same time.
2. **Ship the full license text** — place each license text under `/usr/share/licenses/<component>/` on the ISO.
3. **Provide the corresponding source** — for GPL and LGPL components, make the complete corresponding source available at the same time as the distribution ([`source-flow.md`](source-flow.md)).
4. **Impose no extra conditions** — do not add restrictions or extra clauses to the redistribution of GPL components.
5. **Do not ship what you cannot identify** — do not bundle a component whose license cannot be determined or whose redistribution is not permitted.

### 2.1 Handling of GPLv3

This policy does not forbid GPLv3, but it follows the `config/packages.txt` principle of covering basic utilities with BusyBox (GPL-2.0) applets first. If you install the GNU versions of `bash`, `grep`, `gzip`, `tar` and similar tools, GPLv3 obligations apply (providing installation information, for example), so record the decision to bundle them.

## 3. License Structure

| Subject | License | Full text |
|---------|---------|-----------|
| The project itself (build scripts, configuration, documentation) | MIT | [`../LICENSE`](../LICENSE) |
| Bundled OSS | The license of each component | `/usr/share/licenses/` on the ISO; the inventory is in [`../iso/COPYING`](../iso/COPYING) |

The project being MIT-licensed does not relicense the bundled OSS under MIT. The ISO image as a whole is distributed as a collection of several licenses.

Three points follow from this:

- **The repository is MIT.** Build scripts, configuration files and documentation are the project's own works and are covered by [`../LICENSE`](../LICENSE).
- **The ISO image is a multi-license binary distribution.** Every bundled OSS component remains under its own license, regardless of the repository's MIT license.
- **Distributing the ISO triggers source provision obligations.** Shipping the ISO — by download, on physical media, or by any other means — requires making the complete corresponding source of every GPL and LGPL component available. See section 5 and [`source-flow.md`](source-flow.md).

## 4. Bundled Components

The inventory is based on `config/packages.txt` (base packages) and `config/buildroot-defconfig` (root filesystem composition). Versions are pinned at build time for reproducibility, and the source manifest is authoritative for the exact values.

The "Status" column means:

- **Bundled**: included in the ISO
- **Optional**: not included by default; installed by the user
- **Planned**: the requirement is defined but the component is not bundled yet. When it is bundled, update this table and `iso/COPYING`

### 4.1 Core System

| Component | Status | License | Obligations on distribution | Source |
|-----------|--------|---------|-----------------------------|--------|
| Linux kernel 6.12.34 | Bundled | GPL-2.0-only | Ship the full license text, provide the corresponding source, disclose modifications (`config/kernel-defconfig`) | kernel.org |
| BusyBox | Bundled | GPL-2.0-only | Provide the corresponding source (including the build-time `.config`) | busybox.net |
| musl libc | Bundled | MIT | Ship the copyright notice and the full license text | musl-libc.org |
| OpenRC | Bundled | BSD-2-Clause | Ship the copyright notice and the full license text | github.com/OpenRC/openrc |
| apk-tools | Bundled | GPL-2.0-only | Provide the corresponding source | gitlab.alpinelinux.org/alpine/apk-tools |
| alpine-baselayout | Bundled | GPL-2.0-only | Provide the corresponding source, disclose modifications to configuration files | gitlab.alpinelinux.org/alpine/aports |
| Buildroot (build tool) | Not distributed | GPL-2.0-or-later | No obligation: it is not included in the ISO (build host only) | buildroot.org |

> **About Buildroot**: Buildroot itself is not part of the distribution, but the generated root filesystem contains BusyBox, musl and other components that Buildroot built. Apply the relevant clause to each individual component.

### 4.2 Bootloader and Boot

| Component | Status | License | Obligations on distribution | Source |
|-----------|--------|---------|-----------------------------|--------|
| Limine | Bundled | BSD-2-Clause | Ship the copyright notice and the full license text | github.com/limine-bootloader/limine |
| xorriso / libisoburn | Not distributed | GPL-3.0-or-later | No obligation: it is not included in the ISO (build host only) | gnu.org/software/xorriso |
| mtools | Not distributed | GPL-3.0-or-later | As above | gnu.org/software/mtools |
| dosfstools | Not distributed | GPL-3.0-or-later | As above | github.com/dosfstools/dosfstools |

> The Limine binaries (`limine-bios.sys`, `limine-efi.sys`) are currently placed in `build/limine/` by hand. Because they are bundled in the ISO, **the Limine license text and copyright notice must be installed in `/usr/share/licenses/limine/` at release time**.

### 4.3 Networking

| Component | Status | License | Obligations on distribution | Source |
|-----------|--------|---------|-----------------------------|--------|
| dhcpcd | Bundled | BSD-2-Clause | Ship the copyright notice and the full license text | github.com/NetworkConfiguration/dhcpcd |
| wpa_supplicant | Bundled | BSD-3-Clause | Ship the copyright notice and the full license text | w1.fi |
| wireless-tools | Bundled | GPL-2.0-only | Provide the corresponding source | hpl.hp.com/personal/Jean_Tourrilhes/Linux/Tools.html |
| iptables | Bundled | GPL-2.0-only | Provide the corresponding source | netfilter.org |
| iproute2 | Bundled | GPL-2.0-or-later | Provide the corresponding source | kernel.org (iproute2) |
| OpenSSH (client / server) | Bundled | OpenSSH license (BSD style) | Ship the copyright notice and the full license text | openssh.com |
| dropbear | Optional | MIT | Ship the copyright notice and the full license text | matt.ucc.asn.au/dropbear |

### 4.4 System Management and Utilities

| Component | Status | License | Obligations on distribution | Source |
|-----------|--------|---------|-----------------------------|--------|
| sudo | Bundled | ISC | Ship the copyright notice and the full license text | sudo.ws |
| procps-ng | Bundled | GPL-2.0-or-later / LGPL-2.1-or-later | Provide the corresponding source | gitlab.com/procps-ng/procps |
| cronie | Bundled | MIT and BSD | Ship the copyright notice and the full license text | github.com/cronie-crond/cronie |
| less | Bundled | GPL-3.0-or-later or BSD-2-Clause (dual) | Ship the full text of the license chosen; if GPLv3 is chosen, provide the corresponding source | gnu.org/software/less |
| vi / vim | Bundled | BusyBox applet is GPL-2.0-only, vim is the Vim license | Ship the full text and provide the corresponding source according to what is actually installed | busybox.net / vim.org |
| grep / gzip / tar | Bundled | BusyBox applets are GPL-2.0-only, GNU versions are GPL-3.0-or-later | Provide the corresponding source according to what is actually installed | busybox.net / gnu.org |
| syslog (busybox syslogd) | Bundled | GPL-2.0-only | Provide the corresponding source | busybox.net |
| bash | Optional | GPL-3.0-or-later | Provide the corresponding source and installation information | gnu.org/software/bash |
| Locale / keyboard definitions | Bundled | musl-locales (MIT), Alpine kbd definitions (GPL-2.0 family) | State the origin and license, ship the full text | musl-libc.org / aports |

> `grep`, `gzip`, `tar` and `vi` fall under BusyBox's GPL-2.0 as long as they are provided as BusyBox applets. Installing the GNU versions adds their own licenses.

### 4.5 Japanese Environment (M2: 日本語デスクトップ)

FR-020 から FR-024 で定義された日本語環境のうち、フォント・IME・軽量WM を M2 で同梱する。ロケール・タイムゾーン・キーボードは M1 で rootfs に直接配置済み。

| Component | Status | License | Obligations on distribution | Source |
|-----------|--------|---------|-----------------------------|--------|
| Noto Sans CJK JP | Bundled | SIL OFL 1.1 | Ship the full license text; when modifying, follow the Reserved Font Name rules | github.com/notofonts/noto-cjk |
| IBus | Bundled | LGPL-2.1-or-later | Ship the full license text, provide the corresponding source | github.com/ibus/ibus |
| IBus Mozc | Bundled | BSD-3-Clause | Ship the copyright notice and the full license text | github.com/google/mozc |
| Openbox | Bundled | GPL-2.0-only | Ship the full license text, provide the corresponding source | github.com/dockingsocket/openbox |
| Mozc dictionary data | Bundled | BSD-3-Clause | Ship the full license text; if external dictionaries are mixed in, record their origin and license | github.com/google/mozc |
| Fcitx5 | Optional | LGPL-2.1-or-later | Ship the full license text, provide the corresponding source | github.com/fcitx/fcitx5 |
| IPAex fonts | Optional | IPA Font License 1.0 | Ship the full license text, comply with the modification and redistribution terms | ipa.go.jp/font |

> **Fonts caution**: SIL OFL 1.1 permits modification and redistribution, but a modified version may not use the original Reserved Font Name. If you subset or merge fonts, rename them and record the changes.

### 4.6 Procedure for Additions

When adding a new package to `config/packages.txt`, do all three of the following at the same time.

1. Add a row to the relevant table in this document (license, obligations, source)
2. Mirror the same content in [`../iso/COPYING`](../iso/COPYING)
3. Record the source location and hash in `docs/source-manifest.tsv` (section 5 of [`source-flow.md`](source-flow.md))

## 5. Obligations When Distributing

The obligations in this chapter apply to **distribution of the ISO image**, not to publishing the MIT-licensed repository. Publishing the repository alone creates no GPL or LGPL obligation; shipping the ISO does.

### 5.1 GPL-2.0 (Linux kernel, BusyBox, apk-tools, iptables and others)

- When distributing binaries, provide the complete corresponding source code
- The source must include the configuration needed to build (`.config`, `kernel-defconfig`, `buildroot-defconfig`, patches)
- Ship the full license text and the copyright notice
- Do not impose extra restrictions on redistribution
- Provide the source through one of: together with the binary, by written offer, or from the same server

### 5.2 GPL-3.0 (GNU grep / gzip / tar / bash, xorriso and others)

- In addition to the GPL-2.0 obligations, installation information may have to be provided
- When distributing as a user product, provide a way that does not prevent installing a modified version
- Do not impose additional patent restrictions
- Build-host-only tools (xorriso and others) create no obligation as long as they are not included in the ISO

### 5.3 LGPL-2.1-or-later (IBus, Fcitx5, the procps libraries and others)

- Ship the full license text and the copyright notice
- Provide the corresponding source; with dynamic linking this is required
- When static linking or modifying, provide object files and similar in a form that allows relinking
- State clearly which LGPL parts were modified and what the changes are

### 5.4 SIL OFL 1.1 (Noto CJK and others)

- Ship the full license text
- Do not sell the fonts on their own
- When distributing a modified version, do not use the Reserved Font Name; rename the font
- When embedding in other software, do not restrict extraction and redistribution of the font on its own

### 5.5 MIT / BSD-2 / BSD-3 / ISC

- Ship the copyright notice and the full license text
- BSD-3-Clause includes a condition against using the copyright holder's name for promotion

### 5.6 Custom Licenses (OpenSSH, Vim, IPA Font License)

- Ship the full text of each license and follow its extra conditions (name usage restrictions, treatment of modified versions, and so on)
- If a case is unclear, do not bundle it and ask for review

## 6. License Layout on the ISO

```text
/COPYING                                  # Contents of iso/COPYING (inventory and pointers)
/usr/share/licenses/
├── linux-kernel/COPYING
├── busybox/COPYING
├── musl/COPYING
├── openrc/COPYING
├── apk-tools/COPYING
├── limine/COPYING
├── openssh/LICENCE
└── <component>/...
```

Rules:

- Directory names must match the package names in `config/packages.txt`
- Install license texts unmodified
- For components with multiple licenses, install all of `COPYING`, `LICENSE`, `LICENCE` and `LICENSE.*`
- `/COPYING` serves both as the bundle inventory and as the pointer to each directory

## 7. Source Provision Methods

| Method | When it applies | Implementation |
|--------|-----------------|----------------|
| Include on the same medium | When the source is small enough to fit on the ISO | Include the `scripts/collect-sources.sh` output on the ISO or on a separate volume |
| Download from the same server | When attaching the source bundle to a GitHub Release (the default) | State the tag and its correspondence for every release |
| Written Offer | The last resort when the above are difficult | Issue the offer text and validity period (3 years) as described in [`source-flow.md`](source-flow.md) section 8.3 |

Section 8 states the clause each method satisfies and the conditions a written offer has to meet. For the detailed operating procedure, the manifest format and the pre-release checklist, see [`source-flow.md`](source-flow.md).

## 8. License Compliance System

This chapter is the operational contract behind the policy: it names the clause each distribution route relies on, states the three ways to provide the corresponding source, and describes the automated verification that runs before a release.

### 8.1 Clause Map

| License | Clause | What the clause requires | How SabakanOS meets it |
|---------|--------|--------------------------|------------------------|
| GPL-2.0 | section 3(a) | Conveying object code is allowed only when it is accompanied by the complete corresponding machine-readable source code, on a medium customarily used for software interchange | The source bundle `sabakanos-<version>-source.tar.zst` is attached to the same Release page as the ISO |
| GPL-2.0 | section 3(b) | Alternatively, accompany the object code with a written offer, valid for at least three years, to give any third party a complete machine-readable copy of the corresponding source for a charge no more than the cost of physically performing source distribution | Used for offline or physical media distribution (section 8.2) |
| GPL-2.0 | section 3(c) | Alternatively, accompany the object code with the offer information you received (non-commercial redistribution only) | Downstream redistributors pass on this document and the release notes |
| GPL-3.0 | section 6(a) | Convey the object code accompanied by the Corresponding Source on a durable physical medium customarily used for software interchange | Releases on physical media carry the source bundle on the same medium |
| GPL-3.0 | section 6(b) | Convey the object code accompanied by a written offer, valid for at least three years, to give the recipient (i) a copy of the Corresponding Source on a durable physical medium for a charge no more than the cost of performing this, or (ii) access to copy the Corresponding Source from a network server at no further charge | The written offer used for offline distribution (section 8.2) |
| GPL-3.0 | section 6(d) | Offer equivalent access to the Corresponding Source from the same place at no further charge | The ISO and the source bundle are published from the same Release page |
| GPL-3.0 | section 6, final paragraph | When object code is conveyed in, with, or specifically for a User Product, the Corresponding Source must be accompanied by the Installation Information | SabakanOS does not ship a locked-down User Product; a release that changes this must record the Installation Information |
| LGPL-2.1 | section 4 | Object code may be distributed only when accompanied by the complete corresponding machine-readable source code of the Library, distributed under sections 1 and 2 of the license, on a medium customarily used for software interchange | The source bundle contains the Library sources together with the patches that were applied |
| LGPL-2.1 | section 6 | Distributing a work that combines or links with the Library requires a prominent notice that the Library is used and covered by the license, the license text, the source of the Library including any changes, and a form that lets the recipient relink the work after modifying the Library | Libraries stay dynamically linked; static linking requires shipping the object files and the relink instructions |
| SIL OFL 1.1 | — | The full license text travels with the font, the font is not sold on its own, and a modified version drops the Reserved Font Name | License text installed under `/usr/share/licenses/`; subset fonts are renamed and recorded |

Only the clause numbers matter for a release decision: if a route is used that is not listed for the applicable license, the release is blocked until the route is re-established or the component is removed.

### 8.2 Three Ways to Provide the Source

Exactly three routes are acceptable. Pick one per distribution and record which one was used.

| Route | Clause basis | When it is used | Conditions |
|-------|--------------|-----------------|------------|
| Same medium (source bundled with the binary) | GPL-2.0 section 3(a), GPL-3.0 section 6(a), LGPL-2.1 section 4 | When the bundle fits on the medium or on an accompanying volume | The bundle must be the complete corresponding source, on a medium customarily used for software interchange, and must include the build configuration and patches |
| Same server (download from the same place) | GPL-3.0 section 6(d); GPL-2.0 section 3(a) when the source accompanies the download | The default for GitHub Releases | The source is reachable from the same page as the ISO, at no further charge, and stays reachable for at least three years |
| Written offer | GPL-2.0 section 3(b), GPL-3.0 section 6(b), LGPL-2.1 section 6 | Offline or physical media distribution, or redistribution by a third party | See the conditions below |

A written offer is only valid when **all** of the following hold. These are the conditions of GPL-2.0 section 3(b) and its GPL-3.0 section 6(b) counterpart:

1. It is addressed to **any third party**, not only to the direct recipient or to customers.
2. It stays valid for **at least three years** from the date the object code was distributed.
3. The source is provided for a charge **no more than the cost of physically performing source distribution**.
4. What is offered is a **complete machine-readable copy of the corresponding source code**, including the build configuration and the patches.
5. The offer names the **version and the components** it covers.

Two further rules apply:

- A written offer is an additional route, **not a substitute for the license texts**. The full text of every license and the copyright notices must still be installed under `/usr/share/licenses/`.
- An offer issued under GPL-2.0 section 3(b) or GPL-3.0 section 6(b) must be recorded in the release log and kept for the same three years, because the obligation outlives the release.

The offer template and the operating steps are in [`source-flow.md`](source-flow.md) sections 8.3 and 9.

### 8.3 Automated Verification

`.github/workflows/license-check.yml` runs on every pull request and on every release tag (`v*.*.*`). It fails the run when a compliance item is missing, which stops the release before anything is published.

| Check | Input | Fails when |
|-------|-------|------------|
| Package inventory | `config/packages.txt` | The file is missing or empty, or a package has no license mapping |
| License records | `docs/license.md`, `iso/COPYING` | A package has no row in either file, the row states no license identifier, or the pointer to `/usr/share/licenses/<component>/` is missing |
| Source records | `docs/source-manifest.tsv` (falls back to the template on pull requests) | The header is not the 9-column specification, a row has the wrong column count, a component has no version, license, upstream URL or source URL, the version is not pinned, or the license is not an SPDX expression |
| Hashes and patches | `docs/source-manifest.tsv` | A source archive has no `sha256` or a malformed one (release tag only), or a referenced patch is absent |
| COPYING notices | `iso/COPYING` | A required notice, license family, license directory pointer or the source-provision section is missing |
| Documentation statements | `docs/license.md`, `docs/source-flow.md` | The clause numbers, the three provision routes or the tooling names are not stated, or the documents contain non-English text |
| Source tooling | `scripts/collect-sources.sh`, `scripts/generate-sbom.sh` | A script is missing (release tag only), not executable, or has a shell syntax error |

Two modes are used:

- **review** (pull requests, manual runs) — items that cannot be satisfied yet, such as hashes not recorded before a version is cut, are reported as warnings. Real defects (a missing license row, a broken manifest) still fail.
- **release** (`v*.*.*` tag) — every item is mandatory. The real manifest must exist, the hashes must be filled in, and the source tooling must be present.

To fix a failure, add the missing record rather than suppressing the check: add the row to this document and to `iso/COPYING`, add the component to the manifest with a pinned version and hash, or install the missing license text.

### 8.4 What Automation Cannot Decide

The workflow verifies that records exist and agree with each other. It does not read the built ISO. A human still has to confirm:

- that the files inside the produced ISO match the inventory (the workflow sees the repository, not the image)
- that the license of a new or unusual component really permits redistribution (firmware, dictionary data, fonts with Reserved Font Names)
- that the source bundle really rebuilds the shipped binary
- that no Installation Information obligation was created by the way the image is distributed

## 9. Handling Modifications

- If you make changes that are not in upstream — kernel configuration changes, patch application, font subsetting and so on — include the patches themselves and the way to apply them in the source bundle
- Record the changes in the `patches` column of the manifest described in `docs/source-flow.md`
- Configuration files placed directly into the root filesystem (`rootfs/etc/...`) must be included in the source bundle together with the script that generates them
- For changes to GPL-3.0 components, show the change date and the nature of the change in the file
- Do not remove or alter license notices

## 10. Prohibited Practices and Cautions

| Practice | Reason |
|----------|--------|
| Bundling binaries of unknown license | Redistribution permission cannot be confirmed, creating violation risk |
| Mixing GPL-2.0-only code and GPL-3.0-only code in the same binary | License incompatibility (the Linux kernel with GPL-3.0-only code, for example) |
| Imposing extra usage restrictions or an EULA on GPL components | Violates GPL section 6 and related clauses |
| Omitting the full license text and shipping only a pointer | Fails to meet the bundling obligation |
| Using the original Reserved Font Name on a modified font | Violates the OFL 1.1 conditions |
| Removing Limine's copyright notice | Violates the BSD-2-Clause notice requirement |
| Including secrets (keys, tokens) in the repository or the ISO | Security incident. Prevent it with `.gitignore` and CI |
| Redistributing firmware of unknown origin | Firmware often carries its own clauses and must be verified |

## 11. Pre-Release Checklist

The release owner confirms every item below. A single unchecked item blocks the release.

- [ ] Every binary in the ISO appears in the inventory in this document
- [ ] Every row lists a license and a source location
- [ ] `iso/COPYING` matches the current inventory
- [ ] Every full license text is installed under `/usr/share/licenses/` (including Limine)
- [ ] The `sha256` values in the source manifest match the actual sources
- [ ] The source bundle is attached to the Release, or a Written Offer has been issued
- [ ] The kernel configuration (`config/kernel-defconfig`) and the Buildroot defconfig are included in the source bundle
- [ ] Patches for patched components are included in the source bundle
- [ ] The Reserved Font Name rules are respected
- [ ] No secrets are included (`git grep` and the CI secret scan)
- [ ] License changes are described in the release notes

Compliance items verified by the workflow (section 8.3):

- [ ] `.github/workflows/license-check.yml` passed on the release tag in release mode, with no findings
- [ ] Every package in `config/packages.txt` has a row in this document and a row in `iso/COPYING`
- [ ] `docs/source-manifest.tsv` exists (the template alone is not enough) and every `in_iso=yes` row has a `sha256`
- [ ] `scripts/collect-sources.sh` ran for this version and every component in `build/source-manifest.json` reports `collected`
- [ ] `scripts/generate-sbom.sh` produced `build/SBOM.spdx.json` and `build/SOURCE-MANIFEST.json`
- [ ] The published source bundle contains the extracted sources, the build configuration, `source-manifest.json`, `SOURCE-MANIFEST.json`, `SBOM.spdx.json` and `README.txt`
- [ ] The provision route used for this release is recorded (same medium, same server or written offer)
- [ ] A written offer, if used, satisfies all five conditions of section 8.2 (any third party, three years, cost of distribution only, complete machine-readable source, components named)

## 12. Roles

| Role | Owner | Responsibility |
|------|-------|----------------|
| Adding components | Implementation lanes | Identify the license, update this document and the manifest, install the full license texts |
| Documentation, releases, license compliance | Lane E | Maintain the policy, run the checklist, keep `iso/COPYING` consistent, verify before approving a release |
| License check CI | Lane G2 | Maintain `.github/workflows/license-check.yml`, keep the package mapping in step with `config/packages.txt`, keep the check blocking on a release tag |
| Final approval | Project owner | Decide cases that require a legal judgement |

## 13. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2026-11-13 | Initial version (component inventory, obligations, checklist) |
| 0.2.0 | 2026-11-13 | Added the License Compliance System: clause map (GPL-2.0 section 3, GPL-3.0 section 6, LGPL-2.1 sections 4 and 6), the three source provision routes with the written offer conditions, the automated verification in `.github/workflows/license-check.yml`, and the compliance checklist items |
