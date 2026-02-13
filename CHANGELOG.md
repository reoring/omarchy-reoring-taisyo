# Changelog

## Unreleased

- Add a CSKK ASCII (@) passthrough rule so key-driven apps (e.g. Obsidian Vim mode, Steam games) keep receiving key events.
- apply.sh installs `~/.config/fcitx5/conf/fcitx5-cskk` and generates `~/.local/share/libcskk/rules/passthrough_ascii/rule.toml` from system rules.
- Document the rationale and snippets in `japanese/cskk.md`.
