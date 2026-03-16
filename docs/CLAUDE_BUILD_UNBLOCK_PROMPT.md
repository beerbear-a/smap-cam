あなたは ZootoCam の shader / iOS build blocker 担当です。
GPT 側は UI/UX と album 導線を進めています。あなたは shader 品質そのものに加えて、まず `iOS simulator build が最後まで通る状態` を最優先で回復してください。

前提:
- GPT は `shaders/` と shader パイプライン以外を編集中
- shader 領域は Claude 担当
- いまの最大 blocker は `flutter build ios --simulator --no-codesign` が `impellerc` で止まること
- そのせいで最新 UI を simulator / 実機に反映できない

現状:
- 成功済みの古いビルドはある
- しかし最新コードの再ビルドは止まる
- 詰まっているのは `camera_screen.dart` 側ではなく shader compile
- ぶら下がっているのは以下:
  - `film_pipeline.frag`
  - `legacy/film_iso800.frag`
  - `legacy/film_fuji400.frag`
  - `legacy/film_mono_hp5.frag`
  - `legacy/film_warm.frag`

再現コマンド:
```bash
env LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 PATH="/usr/local/lib/ruby/gems/4.0.0/bin:/usr/local/opt/ruby/bin:/usr/local/bin:/usr/bin:/bin:$PATH" flutter build ios --simulator --no-codesign
```

観測している症状:
- `Running Xcode build...` のまま止まる
- 内部では `flutter_tools.snapshot assemble ... debug_ios_bundle_flutter_assets`
- さらに子で `impellerc` が 4 本ぶら下がる
- それぞれ CPU 0.0 のまま長時間終了しない

あなたのタスク:
1. `shaders/film_pipeline.frag` を見直して、`impellerc` が hang しない状態へ直す
2. `film_preview.dart` の shader 読み込みや uniform 接続が、現在の shader と矛盾していないか確認する
3. できるだけ look は維持する
4. ただし最優先は「iOS simulator build が通ること」
5. 必要なら一時的に複雑な処理を段階的に落としてもよい

絶対条件:
- GPT 側が進めた album / camera UX は触らない
- `camera_screen.dart`, `album_screen.dart`, `photo_viewer_screen.dart` の UX 差分は巻き戻さない
- shader compile blocker の解消に集中する

成功条件:
1. 上の `flutter build ios --simulator --no-codesign` が完走する
2. `impellerc` がハングしない
3. simulator へ再インストール可能になる
4. 変更内容と、もし quality を落としたならその内容を明記する

優先順位:
1. build unblock
2. shader safety
3. look recovery
4. look refinement

GPT 側の最新 non-shader 変更:
- 図鑑は一旦 OFF にした
- album を強化した
- ロール単位 / 1枚単位で `iPhone の写真アプリへ保存` を追加した
- これらは Dart 側 analyze 済み

Claude の返答フォーマット:
- 原因
- 直した shader / pipeline
- build が通ったか
- 画質への影響
- 次に GPT がそのまま simulator / 実機投入してよいか
