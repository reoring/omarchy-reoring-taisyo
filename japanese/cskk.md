# fcitx5-cskk (CSKK) の `@` (Ascii) を "キーイベント素通し" にする

Obsidian (Electron) の Vim キーバインドが効かない / Steam のゲームで WASD が動かない、などの症状を、CSKK の `@` (Ascii) モードでも起こさないためのメモ。

## 背景

- CSKK の `@`(Ascii) は「キーボード配列を US に切り替える」ではなく、「IME が ASCII を確定(コミット)する」モード。
- その場合アプリは "文字" を受け取れる一方で、キーイベントそのものは受け取れず、キー入力ベースの機能(Vim キーバインド、ゲーム入力など)が壊れることがある。

## 方針

libcskk のルールで `PassthroughKeyEvent` を使い、`[direct.ascii]` の大半のキーを "パススルー" させる。

用語:

- `FinishKeyEvent`: CSKK 側で入力処理を終了（アプリにキーを渡さない）
- `PassthroughKeyEvent`: アプリへキーイベントを渡す（実装/環境に依存）

## 設定ファイル

1) CSKK 設定（fcitx5 側）

- `~/.config/fcitx5/conf/fcitx5-cskk`

最低限:

```ini
Rule=passthrough_ascii
```

2) libcskk ルール（cskk の変換/コマンド定義）

- `~/.local/share/libcskk/rules/metadata.toml`
  - ルール一覧。`[passthrough_ascii]` を追加する

```toml
[passthrough_ascii]
name = "Passthrough ASCII"
description = "default rule with ASCII passthrough"
path = "passthrough_ascii"
```

- `~/.local/share/libcskk/rules/passthrough_ascii/rule.toml`
  - `default` ルールをベースに、`[direct.ascii]` だけパススルー中心に差し替える

## ルール断片

`direct.hiragana` の `l` で Ascii に入る挙動はそのまま:

```toml
[direct.hiragana]
"l" = ["ForceKanaConvert(Hiragana)", "ChangeInputMode(Ascii)", "ClearUnconfirmedInputs"]
```

`direct.ascii` でキーを "文字コミット" ではなく "キーイベント" として渡す:

```toml
[direct.ascii]
"C-g" = ["PassthroughKeyEvent"]
"C-j" = ["ChangeInputMode(Hiragana)"]

"w" = ["PassthroughKeyEvent"]
"a" = ["PassthroughKeyEvent"]
"s" = ["PassthroughKeyEvent"]
"d" = ["PassthroughKeyEvent"]
"h" = ["PassthroughKeyEvent"]
"j" = ["PassthroughKeyEvent"]
"k" = ["PassthroughKeyEvent"]
"l" = ["PassthroughKeyEvent"]
```

実際は、英数・記号・矢印キー等も広めにパススルーする方がトラブルが少ない。

補足:

- Vim/アプリ側の `Ctrl-*` ショートカットも素通ししたいことが多い（例: `C-a`..`C-z`, `C-[`, `C-]` など）。
- Shift 記号は環境によって `(shift 4)` のように "修飾付き" として来たり、`(shift dollar)` のように "既にshift済み keysym + Shift 修飾" で来ることもあるため、両方をカバーする方が安全。

## このリポジトリでの反映

`apply.sh` が以下を行う:

1) `home/.config/fcitx5/conf/fcitx5-cskk` を `~/.config/fcitx5/conf/fcitx5-cskk` へインストール
2) `~/.local/share/libcskk/rules` を整備
   - `metadata.toml` が無ければ `/usr/share/libcskk/rules/metadata.toml` をコピー
   - `default/rule.toml` が無ければ `/usr/share/libcskk/rules/default/rule.toml` をコピー
   - `metadata.toml` に `passthrough_ascii` が無ければ追記
   - `/usr/share/libcskk/rules/default/rule.toml` を元に `passthrough_ascii/rule.toml` を生成し、`[direct.ascii]` をパススルー中心に差し替え

補足:

- libcskk は `~/.local/share/libcskk/rules` が存在するとそちらを優先する。
- `metadata.toml` だけ作ってベースルールが欠ける状態になると、fcitx5-cskk が CSKK コンテキスト生成に失敗しやすい。

## `libcskk.so` が見つからない場合（cskk-git）

Arch の `cskk-git` は `libcskk.so` を `/usr/lib/cskk/` に置くため、そのままだと `fcitx5-cskk` が `libcskk.so.*` をロードできないことがある。

このリポジトリは systemd user override で `LD_LIBRARY_PATH` を追加する:

- `~/.config/systemd/user/app-org.fcitx.Fcitx5@autostart.service.d/override.conf`
  - `Environment=LD_LIBRARY_PATH=/usr/lib/cskk`

確認例:

```sh
ldd /usr/lib/fcitx5/fcitx5-cskk.so | rg -i 'libcskk|not found'
```

## 反映/再起動

適用後に fcitx を再起動すると確実:

```sh
systemctl --user restart app-org.fcitx.Fcitx5@autostart.service
```

## Steam 側の逃げ道（個別ゲーム）

環境によっては Steam/SDL 側に IME の影響が残ることがある。その場合、ゲームの起動オプションで抑止できる:

```text
SDL_IM_MODULE=none XMODIFIERS=@im=none %command%
```
