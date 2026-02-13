# Changelog

## Unreleased

- Add a CSKK ASCII (@) passthrough rule so key-driven apps (e.g. Obsidian Vim mode, Steam games) keep receiving key events.
- apply.sh installs `~/.config/fcitx5/conf/fcitx5-cskk` and generates `~/.local/share/libcskk/rules/passthrough_ascii/rule.toml` from system rules.
- Document the rationale and snippets in `japanese/cskk.md`.
- Add a WWAN latency switcher helper + setup script and test coverage.
- Add a mpvpaper live wallpaper setup helper.
- Adjust Hyprland AltGr workspace routing and extend `hypr-ws` for internal/external monitor targets.
