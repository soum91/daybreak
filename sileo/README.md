# Daybreak Sileo APT source

This directory is the live unsigned APT source, served over HTTPS from GitHub raw.
`Packages`, compressed indexes, `Release`, and `debs/` are populated **only after** a
successful macOS rootless tweak build. There is no placeholder .deb.

Add this source in Sileo:

https://raw.githubusercontent.com/soum91/daybreak/main/sileo/

The source is not GPG signed. Sileo may display a warning about unsigned sources.
If it does not support GitHub's raw HTTP redirects, a GitHub Pages mirror must be
enabled before the source is usable; do not claim installation was tested.
