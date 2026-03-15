# AI Handoff — 2026-03-14

この文書は、Claude や別の AI へ現在の実装状況を引き継ぐための短期メモです。
長期の思想や背景は `CLAUDE.md` を参照してください。

## 1. 結論

オーナー判断として、今は **zoo app を広げるより camera app として仕上げる段階** です。

外部の実装者として見ても、この判断は妥当です。理由は次の通りです。

- 体験の芯は「動物園情報」よりも「一本のロールとして思い出を残すこと」にある
- Camera / Develop / Album の UX が整うと、Zoo / Map / Zukan は addon として自然に乗る
- 逆に、カメラ体験が弱いまま周辺機能を足すとアプリ全体が散る

もし異論があるなら、追加したい zoo 機能が `camera-first` の体験価値をどう強化するかを明示してから着手してください。

## 1.5 並行開発ルール

- Claude と GPT で並行開発する場合は `docs/PAIR_SYNC_PROTOCOL.md` を先に読む
- 短い10分更新は `docs/ONETIME_SYNC_NOTE.md` を使う
- `onetime.me` に流すのは長文 handoff ではなく、この短い sync note を推奨

## 2. 現在の主要フロー

### カメラ

- メインタブは `Camera / Album / Map / Zukan / Settings`
- 下部バーのラベルは設定から ON/OFF 可能
- カメラ画面はファインダー優先
  - フラッシュは右上
  - セッション状態は上部中央
  - 右下メニューは閉じた状態がデフォルトで、押すとふわっと開く
  - 焦点距離 UI は iPhone 寄りで、35mm がデフォルト
- シャッター時の白フラッシュはファインダー内部だけに出る

### フィルムモード

- 27枚撮り切るまで同じロールを使う
- 途中でルック変更不可
- 1日1本まで
- 撮り切ったら `developing` に移行し、1時間待ち
- 現像完了後にインデックスシートを保存
- フィルムからインスタントへ切り替える時は警告を表示
- 切り替え時、実際には消さず `shelved` 扱い
- 設定画面から復元可能。ただし 1 本ごとに 7 日に 1 回のみ

### インスタントモード

- すぐ使える
- 電池 100 ショット
- インデックスシートなし
- フィルムより自由で、軽い記録用の位置づけ

### 現像

- `DevelopScreen` は 3 状態
  - 現像待ち
  - 現像中
  - 現像完了
- `Pro` は現在プレビュー実装
  - 1時間待ちスキップのみ
  - 実課金接続は未実装
- 1年以上放置した `developing` ロールは、起動時に自動現像ダイアログを出す
  - これはシステム通知ではなくアプリ内ダイアログ

### アルバム

- 現在のロール
- 現像待ち
- 最近のカット
- 現像済みアーカイブ

という4つの見せ方がある。

- 写真グリッドだけ角丸
- 写真詳細は横スワイプで送れる
- 現像完了後は
  - インデックスシートを確認
  - 1枚ずつ見る
  - メモを書く
  - アルバムへ戻る
  の流れがある

### メモ

- `JournalScreen` でロールメモと写真ごとのメモを編集
- `PhotoViewerScreen` から該当カットのメモ編集へ入れる

## 3. まだ zoo-first の名残がある場所

- `CheckInScreen`
  - 画面名と導線がまだ `チェックイン` 中心
  - 中身も zoo リスト前提が強い
  - 将来的には `Start Roll` か `New Session` に近づける余地が大きい
- `MapScreen`
  - 現像済みセッション確認には使える
  - ただし現在は camera-first の主導線ではない
- `ZukanScreen`
  - 動く
  - ただし今の最優先ではない

## 4. ナビゲーション上の現在地

最近の修正で、以下は最低限そろっています。

- `Album` から撮影再開しても下部バーが消えない
- `DevelopScreen` に戻るボタンあり
- `DevelopScreen` からアルバムへ戻れる
- `PhotoViewerScreen` からアルバムへ戻れる
- `Zukan` 詳細の「記録した場所」から写真ビューアへ飛べる

つまり、主な「戻れない」「矢印があるのに飛べない」は一旦つぶしてあります。

## 5. 既知の技術的な残課題

`flutter analyze` の残りは 2026-03-14 時点で以下です。

- `lib/features/map/map_screen.dart`
  - Mapbox の annotation tap listener が deprecated
- `lib/features/share/contact_sheet_service.dart`
  - `prefer_const_declarations` が数件
- `lib/features/share/watermark_service.dart`
  - `prefer_const_declarations` が 1 件
- `lib/features/zukan/widgets/animal_silhouette.dart`
  - 未使用ローカル変数 warning
- 焦点距離の挙動
  - Flutter 側にはズームアニメーションあり
  - iOS 側には `setFocalLength` を追加して、`AVFoundation` で wide / ultra wide / tele 切替とズームランプを行う実装を入れてある
  - ただしこれは iOS ネイティブ実装で、Android 側にはまだ同等のネイティブ焦点距離制御は入っていない
  - 実機での微調整余地は残るが、もう「将来の完全未着手課題」ではない

致命傷ではないですが、別 AI が「コード品質を上げる」タスクを取るなら最初の掃除候補です。

## 6. シミュレーターとモック

- シミュレーターカメラはローカルのモック画像をランダム使用
- アルバムにも同じモック系のテストデータを投入できる状態
- UI 確認は iPhone 16 Pro シミュレーター前提で進めていた

## 7. 動作確認コマンド

```bash
flutter analyze
flutter test test/widget_test.dart
```

2026-03-14 時点では `widget_test.dart` は通過済みです。

## 8. 次に着手するなら

優先順はこの順がよいです。

1. `CheckInScreen` を zoo-first から camera-first の開始画面へ寄せる
2. カメラの micro UX を詰める
3. アルバムのロール詳細とメモ体験を磨く
4. その後に Map / Zukan を addon としてなじませる

## 9. 触らないほうがよい前提

- フィルムの不自由さは意図
- インデックスシートはフィルムだけの特権
- インスタントは便利だが制限付き
- 動物園機能をいま主役に戻さない

この 4 点を崩す提案は、オーナー確認なしで進めないでください。
