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

Arch の `cskk-git` は `libcskk.so` を `/usr/lib/cskk/` に置く。これは動的リンカーのデフォルト検索パスに含まれないため、そのままだと `fcitx5-cskk.so` が `libcskk.so.3` を dlopen できず、CSKK アドオンが fcitx5 のロード一覧から静かに消える。

`apply.sh` は `/etc/ld.so.conf.d/cskk.conf` に `/usr/lib/cskk` を登録して `ldconfig` を走らせることで、システム全体で解決する。fcitx5 の起動方法（systemd user service / Hyprland `exec-once` / 手動）に依存しない堅牢な方法。

手動で適用する場合:

```sh
echo '/usr/lib/cskk' | sudo tee /etc/ld.so.conf.d/cskk.conf
sudo ldconfig
```

確認:

```sh
ldd /usr/lib/fcitx5/fcitx5-cskk.so | rg -i 'libcskk|not found'
# libcskk.so.3 => /usr/lib/cskk/libcskk.so.3 と出れば OK
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
