Framework to build NGFW and WAF ISO images.

# Differences with upstream

We maintain this repository with the patches under `patches/` directly
applied, so it's easy to migrate to the latest Debian stable release.

If you need to modify some of upstream's behavior in `debian-cd/`,
`installer-pkgs-modified/` or `d-i/`, please make sure you do so by
editing the patches under `patches/`, and testing they apply correctly
with `make unpatch` and `make patch`.

Note: `patches/logo_arista.png` is not really a patch, but is used as
a drop-in replacement for the Debian logo during `make patch`, hence its
questionable location.

# Upstream code

## installer-pkgs-modified/

We modify a couple of Debian udebs, mostly for branding purposes:

- base-installer
- cdebconf
- pkgsel
- rootskel-gtk

## d-i/

We build the official Debian installer ourselves, so it uses the
Untangle kernel and our branding.

## debian-cd/

Also modified for branding, through `patches/`.

# In-house code

## Makefile

Main entrypoint for all operations.

## cd-root/

Static content found on the ISO, for branding and serial install.

## profiles/

Definition of how to build our images (packages, preseeding, postinsts,
etc).
