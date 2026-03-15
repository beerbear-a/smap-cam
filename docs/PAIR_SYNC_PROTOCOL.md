# Pair Sync Protocol

この文書は、GPT と Claude が `ZootoCam` を並行開発するときの共通運用ルールです。

最終更新: 2026-03-14

## 1. 目的

- 同じ場所を二重実装しない
- 10分単位で進捗を共有する
- camera-first の方針を崩さない
- 長文 handoff と短文 sync を分ける

## 2. 役割分担

### Claude

- shader / film look / rendering pipeline
- 写ルンです ISO 800 の再現
- フィルム感の質感設計

### GPT

- Flutter 側の接続
- カメラ UI / 現像 / アルバム / 設定 / 導線整理
- ネイティブ連携
- 破綻修正
- テスト / analyze / simulator 確認

## 3. 共通で守ること

- 最優先は `camera-first`
- 動物園機能は addon として扱う
- ファインダーを邪魔する UI は増やさない
- 戻る導線を必ず残す
- 変更後は最低限 `flutter analyze` を回す

## 4. 共有ドキュメントの使い分け

### 長文の正本

- `CLAUDE.md`
- `docs/AI_HANDOFF_2026-03-14.md`

### 短文の同期用

- `docs/ONETIME_SYNC_NOTE.md`

これは `onetime.me` 系の一回きり共有へ貼る前提の短いメモです。

## 5. 10分更新ルール

10分ごとに共有する内容は次の4点だけでよいです。

1. いま触っている領域
2. 何を変えたか
3. 何を壊していないか
4. 次の10分でやること

## 6. 禁止事項

- shader 担当と UI 担当が同じファイルを同時に大きく触る
- zoo-first の文脈を主導線へ戻す
- handoff を更新せずに大きな方向転換をする

## 7. 推奨フロー

1. 長文 handoff を読む
2. 自分の担当だけ進める
3. `docs/ONETIME_SYNC_NOTE.md` を更新する
4. 必要なら `onetime.me` に短文だけ流す
5. まとまった節目で `docs/AI_HANDOFF_2026-03-14.md` を更新する
