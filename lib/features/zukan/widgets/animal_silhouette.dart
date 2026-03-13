import 'package:flutter/material.dart';

// ── 西村 晴子（動物学アドバイザー）の分類体系に基づく実装
// ── Rei Suzuki: 全シルエットを CustomPainter + Path で描く。アセットファイルは一枚も使わない。

// ─────────────────────────────────────────────────────────
// シルエットベースカテゴリ（7分類）
// ─────────────────────────────────────────────────────────

enum SilhouetteBase {
  felid,        // 大型猫科型
  ursid,        // クマ・パンダ型
  primate,      // 霊長類型
  megaherbivore, // 大型草食獣型
  smallMammal,  // 小型哺乳類型
  avian,        // 鳥類型
  reptile,      // 爬虫類型
}

// ─────────────────────────────────────────────────────────
// 差分パラメータ定義
// ─────────────────────────────────────────────────────────

enum EarType {
  none,
  smallRound,
  mediumRound,
  pointedSmall,
  pointedLarge,
  fanLarge,      // ゾウ
  veryLarge,     // フェネック
  rabbitLong,    // ツチブタ
  tufted,        // ビンツロング
}

enum TailType {
  none,
  stub,
  veryShort,
  mediumThin,
  mediumFluffy,
  longCurved,
  veryLongFluffy,
  veryLongTapered,
  tailFan,       // 鳥の尾羽
  longPrehensile,
  bushy,
}

enum BodyShape {
  slender,
  medium,
  muscular,
  round,
  barrel,
  massiveRound,
  veryLarge,
  longArmed,   // オランウータン
  longFlat,    // 爬虫類
  horseLike,
  horseTall,   // キリン（体はウマ型だが首が非常に長い）
  streamlined,
}

// 固有パーツ（種を一発で識別させる要素）
enum UniqueFeature {
  none,
  trunk,        // ゾウの鼻
  shortTrunk,   // バクの短い鼻
  veryLongNeck, // キリン
  wideMouth,    // カバ
  doubleHorn,   // シロサイ
  mane,         // ライオン♂
  knuckleWalk,  // ゴリラ
  colorfulFace, // マンドリル
  redFace,      // ニホンザル
  eyePatches,   // ジャイアントパンダ
  chestPatch,   // マレーグマ
  scales,       // センザンコウ
  longSnout,    // ツチブタ
  curvedNeck,   // フラミンゴ
  stripes,      // シマウマ
  // ── 西村アドバイザー 修正追加 (2026-03-14) ──────────────
  legStripes,   // オカピ（後肢・臀部の白黒縞）
  upright,      // ミーアキャット（直立二足姿勢）
}

// ─────────────────────────────────────────────────────────
// 種ごとの設定テーブル
// ─────────────────────────────────────────────────────────

class SilhouetteConfig {
  final SilhouetteBase base;
  final EarType ears;
  final TailType tail;
  final BodyShape body;
  final UniqueFeature unique;

  const SilhouetteConfig({
    required this.base,
    this.ears = EarType.smallRound,
    this.tail = TailType.mediumThin,
    this.body = BodyShape.medium,
    this.unique = UniqueFeature.none,
  });
}

// asset_key → SilhouetteConfig マッピング（西村アドバイザー監修）
const Map<String, SilhouetteConfig> _configs = {
  // ── 大型猫科 ─────────────────────────────────────────
  'lion':         SilhouetteConfig(base: SilhouetteBase.felid, ears: EarType.pointedSmall, tail: TailType.longCurved, body: BodyShape.muscular, unique: UniqueFeature.mane),
  'tiger':        SilhouetteConfig(base: SilhouetteBase.felid, ears: EarType.pointedSmall, tail: TailType.longCurved, body: BodyShape.muscular),
  'snow_leopard': SilhouetteConfig(base: SilhouetteBase.felid, ears: EarType.pointedSmall, tail: TailType.veryLongFluffy, body: BodyShape.medium),
  'cheetah':      SilhouetteConfig(base: SilhouetteBase.felid, ears: EarType.pointedSmall, tail: TailType.longCurved, body: BodyShape.slender),
  'clouded_leopard': SilhouetteConfig(base: SilhouetteBase.felid, ears: EarType.pointedSmall, tail: TailType.longCurved, body: BodyShape.medium),
  'amur_leopard': SilhouetteConfig(base: SilhouetteBase.felid, ears: EarType.pointedSmall, tail: TailType.longCurved, body: BodyShape.medium),

  // ── クマ・パンダ ──────────────────────────────────────
  'polar_bear':   SilhouetteConfig(base: SilhouetteBase.ursid, ears: EarType.smallRound, tail: TailType.veryShort, body: BodyShape.veryLarge),
  'sun_bear':     SilhouetteConfig(base: SilhouetteBase.ursid, ears: EarType.smallRound, tail: TailType.veryShort, body: BodyShape.medium, unique: UniqueFeature.chestPatch),
  'giant_panda':  SilhouetteConfig(base: SilhouetteBase.ursid, ears: EarType.mediumRound, tail: TailType.veryShort, body: BodyShape.round, unique: UniqueFeature.eyePatches),
  'red_panda':    SilhouetteConfig(base: SilhouetteBase.ursid, ears: EarType.smallRound, tail: TailType.mediumFluffy, body: BodyShape.slender), // 修正: pointedSmall → smallRound (西村 2026-03-14)

  // ── 霊長類 ───────────────────────────────────────────
  'gorilla':      SilhouetteConfig(base: SilhouetteBase.primate, ears: EarType.smallRound, tail: TailType.none, body: BodyShape.muscular, unique: UniqueFeature.knuckleWalk),
  'chimp':        SilhouetteConfig(base: SilhouetteBase.primate, ears: EarType.mediumRound, tail: TailType.none, body: BodyShape.medium),
  'orangutan':    SilhouetteConfig(base: SilhouetteBase.primate, ears: EarType.smallRound, tail: TailType.none, body: BodyShape.longArmed),
  'mandrill':     SilhouetteConfig(base: SilhouetteBase.primate, ears: EarType.smallRound, tail: TailType.stub, body: BodyShape.medium, unique: UniqueFeature.colorfulFace),
  'snow_monkey':  SilhouetteConfig(base: SilhouetteBase.primate, ears: EarType.smallRound, tail: TailType.mediumThin, body: BodyShape.medium, unique: UniqueFeature.redFace),

  // ── 大型草食獣 ────────────────────────────────────────
  'elephant':     SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.fanLarge, tail: TailType.mediumThin, body: BodyShape.barrel, unique: UniqueFeature.trunk),
  'giraffe':      SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.pointedLarge, tail: TailType.mediumThin, body: BodyShape.horseTall, unique: UniqueFeature.veryLongNeck),
  'hippo':        SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.smallRound, tail: TailType.stub, body: BodyShape.massiveRound, unique: UniqueFeature.wideMouth),
  'pygmy_hippo':  SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.smallRound, tail: TailType.stub, body: BodyShape.round),
  'zebra':        SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.pointedLarge, tail: TailType.mediumThin, body: BodyShape.horseLike, unique: UniqueFeature.stripes),
  'tapir':        SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.pointedLarge, tail: TailType.stub, body: BodyShape.barrel, unique: UniqueFeature.shortTrunk),
  'okapi':        SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.pointedLarge, tail: TailType.mediumThin, body: BodyShape.horseLike, unique: UniqueFeature.legStripes), // 修正: 後肢縞追加 (西村 2026-03-14)
  'white_rhino':  SilhouetteConfig(base: SilhouetteBase.megaherbivore, ears: EarType.pointedLarge, tail: TailType.stub, body: BodyShape.veryLarge, unique: UniqueFeature.doubleHorn),

  // ── 小型哺乳類 ────────────────────────────────────────
  'capybara':     SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.smallRound, tail: TailType.none, body: BodyShape.barrel),
  'meerkat':      SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.pointedSmall, tail: TailType.mediumThin, body: BodyShape.slender, unique: UniqueFeature.upright), // 修正: 直立明示 (西村 2026-03-14)
  'fennec':       SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.veryLarge, tail: TailType.bushy, body: BodyShape.slender),
  'otter':        SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.smallRound, tail: TailType.mediumThin, body: BodyShape.streamlined),
  'binturong':    SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.tufted, tail: TailType.longPrehensile, body: BodyShape.medium),
  'pangolin':     SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.smallRound, tail: TailType.longCurved, body: BodyShape.medium, unique: UniqueFeature.scales),
  'aardvark':     SilhouetteConfig(base: SilhouetteBase.smallMammal, ears: EarType.rabbitLong, tail: TailType.mediumThin, body: BodyShape.barrel, unique: UniqueFeature.longSnout),

  // ── 鳥類 ─────────────────────────────────────────────
  'flamingo':     SilhouetteConfig(base: SilhouetteBase.avian, ears: EarType.none, tail: TailType.tailFan, body: BodyShape.slender, unique: UniqueFeature.curvedNeck),

  // ── 爬虫類 ───────────────────────────────────────────
  'komodo':       SilhouetteConfig(base: SilhouetteBase.reptile, ears: EarType.none, tail: TailType.veryLongTapered, body: BodyShape.longFlat),
};

// ─────────────────────────────────────────────────────────
// AnimalSilhouette ウィジェット
// ─────────────────────────────────────────────────────────

class AnimalSilhouette extends StatelessWidget {
  final String assetKey;
  final double size;
  final Color color;

  const AnimalSilhouette({
    super.key,
    required this.assetKey,
    required this.size,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final config = _configs[assetKey];
    return CustomPaint(
      size: Size(size, size),
      painter: _SilhouettePainter(
        config: config,
        color: color,
        assetKey: assetKey,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// _SilhouettePainter: ベース + 差分パーツを組み合わせて描画
// ─────────────────────────────────────────────────────────

class _SilhouettePainter extends CustomPainter {
  final SilhouetteConfig? config;
  final Color color;
  final String assetKey;

  _SilhouettePainter({
    required this.config,
    required this.color,
    required this.assetKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (config == null) {
      _drawFallback(canvas, size, paint);
      return;
    }

    final cfg = config!;
    final path = Path();

    switch (cfg.base) {
      case SilhouetteBase.felid:
        _drawFelid(path, size, cfg);
      case SilhouetteBase.ursid:
        _drawUrsid(path, size, cfg);
      case SilhouetteBase.primate:
        _drawPrimate(path, size, cfg);
      case SilhouetteBase.megaherbivore:
        _drawMegaherbivore(path, size, cfg);
      case SilhouetteBase.smallMammal:
        _drawSmallMammal(path, size, cfg);
      case SilhouetteBase.avian:
        _drawAvian(path, size, cfg);
      case SilhouetteBase.reptile:
        _drawReptile(path, size, cfg);
    }

    canvas.drawPath(path, paint);
  }

  // ── Base 1: 大型猫科型 ─────────────────────────────────

  void _drawFelid(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    // 胴体（低重心・流線型）
    p.addOval(Rect.fromLTWH(w * 0.15, h * 0.35, w * 0.55, h * 0.35));

    // 頭
    final headR = w * 0.16;
    p.addOval(Rect.fromCenter(
      center: Offset(w * 0.75, h * 0.28),
      width: headR * 2,
      height: headR * 1.8,
    ));

    // 首（胴体と頭をつなぐ）
    p.addRect(Rect.fromLTWH(w * 0.6, h * 0.28, w * 0.14, h * 0.2));

    // 前足 x2
    _drawLeg(p, Offset(w * 0.28, h * 0.65), w * 0.07, h * 0.22, isFront: true);
    _drawLeg(p, Offset(w * 0.42, h * 0.65), w * 0.07, h * 0.22, isFront: true);

    // 後足 x2
    _drawLeg(p, Offset(w * 0.18, h * 0.63), w * 0.07, h * 0.20);
    _drawLeg(p, Offset(w * 0.56, h * 0.63), w * 0.07, h * 0.20);

    // 耳
    _drawEars(p, Offset(w * 0.75, h * 0.28), w * 0.16, cfg.ears);

    // 尾（細長く弧を描く）
    if (cfg.tail != TailType.none) {
      _drawFelicTail(p, Offset(w * 0.15, h * 0.50), cfg.tail, w, h);
    }

    // たてがみ（ライオン♂）
    if (cfg.unique == UniqueFeature.mane) {
      p.addOval(Rect.fromCenter(
        center: Offset(w * 0.75, h * 0.30),
        width: w * 0.42,
        height: w * 0.40,
      ));
    }
  }

  // ── Base 2: クマ・パンダ型 ────────────────────────────

  void _drawUrsid(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    // 胴体（ずんぐり）
    final bodyW = cfg.body == BodyShape.veryLarge ? w * 0.65
        : cfg.body == BodyShape.round ? w * 0.58
        : w * 0.52;
    p.addOval(Rect.fromLTWH(w * 0.18, h * 0.30, bodyW, h * 0.40));

    // 頭（大きくて丸い）
    final headR = cfg.body == BodyShape.round ? w * 0.20 : w * 0.17;
    p.addOval(Rect.fromCenter(
      center: Offset(w * 0.74, h * 0.25),
      width: headR * 2,
      height: headR * 2,
    ));

    // 首
    p.addRect(Rect.fromLTWH(w * 0.60, h * 0.27, w * 0.14, h * 0.18));

    // 4本足（太く短い）
    for (final dx in [0.22, 0.36, 0.50, 0.62]) {
      p.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * dx, h * 0.65, w * 0.09, h * 0.20),
        const Radius.circular(4),
      ));
    }

    // 丸い耳
    _drawEars(p, Offset(w * 0.74, h * 0.25), headR, cfg.ears);

    // 目のパッチ（パンダ）
    if (cfg.unique == UniqueFeature.eyePatches) {
      final eyePaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
      // ペイントは config color に依存するので省略、形状だけ追加
      p.addOval(Rect.fromCenter(center: Offset(w * 0.68, h * 0.22), width: w * 0.10, height: w * 0.07));
      p.addOval(Rect.fromCenter(center: Offset(w * 0.80, h * 0.22), width: w * 0.10, height: w * 0.07));
    }
  }

  // ── Base 3: 霊長類型 ──────────────────────────────────

  void _drawPrimate(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    final isKnuckle = cfg.unique == UniqueFeature.knuckleWalk;
    final isLongArmed = cfg.body == BodyShape.longArmed;

    // 胴体
    p.addOval(Rect.fromLTWH(
      w * 0.28, h * (isKnuckle ? 0.35 : 0.28),
      w * 0.44, h * 0.35,
    ));

    // 頭
    final headR = w * 0.15;
    final headY = isKnuckle ? h * 0.22 : h * 0.12;
    p.addOval(Rect.fromCenter(
      center: Offset(w * 0.50, headY),
      width: headR * 2, height: headR * 2,
    ));

    // 首
    p.addRect(Rect.fromLTWH(w * 0.43, headY + headR, w * 0.14, h * 0.10));

    // 腕（長い）
    final armLength = isLongArmed ? h * 0.48 : h * 0.35;
    _drawArm(p, Offset(w * 0.28, h * 0.40), armLength, isLeft: true);
    _drawArm(p, Offset(w * 0.72, h * 0.40), armLength, isLeft: false);

    // 足
    _drawLeg(p, Offset(w * 0.35, h * 0.60), w * 0.10, h * 0.28);
    _drawLeg(p, Offset(w * 0.55, h * 0.60), w * 0.10, h * 0.28);

    // 耳
    _drawEars(p, Offset(w * 0.50, headY), headR, cfg.ears);
  }

  // ── Base 4: 大型草食獣型 ──────────────────────────────

  void _drawMegaherbivore(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    final isGiraffe = cfg.unique == UniqueFeature.veryLongNeck;
    final isElephant = cfg.unique == UniqueFeature.trunk;

    // 胴体
    final bodyY = isGiraffe ? h * 0.40 : h * 0.28;
    final bodyH = cfg.body == BodyShape.massiveRound ? h * 0.42
        : cfg.body == BodyShape.barrel ? h * 0.38
        : h * 0.30;
    p.addOval(Rect.fromLTWH(w * 0.12, bodyY, w * 0.60, bodyH));

    // キリンの長い首
    if (isGiraffe) {
      p.addRect(Rect.fromLTWH(w * 0.60, h * 0.08, w * 0.10, h * 0.38));
      // 頭
      p.addOval(Rect.fromLTWH(w * 0.56, h * 0.04, w * 0.18, h * 0.12));
    } else {
      // 通常の首と頭
      p.addRect(Rect.fromLTWH(w * 0.60, h * 0.22, w * 0.12, h * 0.16));
      p.addOval(Rect.fromLTWH(
        isElephant ? w * 0.58 : w * 0.62,
        h * 0.14,
        w * 0.20, h * 0.16,
      ));
    }

    // 4本足
    final legY = bodyY + bodyH - h * 0.04;
    for (final dx in [0.16, 0.28, 0.48, 0.60]) {
      p.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * dx, legY, w * 0.09, h * 0.24),
        const Radius.circular(3),
      ));
    }

    // 耳
    final headCenter = isGiraffe
        ? Offset(w * 0.65, h * 0.08)
        : Offset(w * 0.72, h * 0.22);
    _drawEars(p, headCenter, w * 0.10, cfg.ears);

    // 固有パーツ
    switch (cfg.unique) {
      case UniqueFeature.trunk:
        // ゾウの鼻（下に垂れる曲線）
        final trunkPath = Path()
          ..moveTo(w * 0.68, h * 0.28)
          ..quadraticBezierTo(w * 0.58, h * 0.50, w * 0.65, h * 0.60)
          ..lineTo(w * 0.70, h * 0.60)
          ..quadraticBezierTo(w * 0.64, h * 0.50, w * 0.73, h * 0.28)
          ..close();
        p.addPath(trunkPath, Offset.zero);
      case UniqueFeature.doubleHorn:
        // サイの角
        p.addOval(Rect.fromLTWH(w * 0.78, h * 0.16, w * 0.05, h * 0.10));
        p.addOval(Rect.fromLTWH(w * 0.74, h * 0.20, w * 0.04, h * 0.08));
      case UniqueFeature.shortTrunk:
        // バクの短い鼻
        p.addOval(Rect.fromLTWH(w * 0.79, h * 0.20, w * 0.08, h * 0.08));
      case UniqueFeature.legStripes:
        // オカピ: 後肢の白黒縞（後ろ2本の足に縞ストライプを重ねる）
        final stripeY = bodyY + bodyH - h * 0.02;
        for (int i = 0; i < 4; i++) {
          p.addRect(Rect.fromLTWH(
            w * 0.48 + i * (w * 0.025),
            stripeY,
            w * 0.012,
            h * 0.22,
          ));
          p.addRect(Rect.fromLTWH(
            w * 0.60 + i * (w * 0.025),
            stripeY,
            w * 0.012,
            h * 0.22,
          ));
        }
      default:
        break;
    }
  }

  // ── Base 5: 小型哺乳類型 ─────────────────────────────

  void _drawSmallMammal(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    final isUpright = cfg.unique == UniqueFeature.upright; // 直立姿勢（ミーアキャット等）

    if (isUpright) {
      // 直立姿勢（ミーアキャット）
      p.addOval(Rect.fromLTWH(w * 0.35, h * 0.30, w * 0.30, h * 0.40));
      p.addOval(Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.20),
        width: w * 0.22, height: w * 0.22,
      ));
      // 2足立ち
      _drawLeg(p, Offset(w * 0.37, h * 0.68), w * 0.10, h * 0.22);
      _drawLeg(p, Offset(w * 0.53, h * 0.68), w * 0.10, h * 0.22);
    } else {
      // 通常の4足姿勢
      final bodyW = cfg.body == BodyShape.barrel ? w * 0.52 : w * 0.46;
      p.addOval(Rect.fromLTWH(w * 0.20, h * 0.35, bodyW, h * 0.30));
      p.addOval(Rect.fromCenter(
        center: Offset(w * 0.76, h * 0.32),
        width: w * 0.22, height: w * 0.20,
      ));
      p.addRect(Rect.fromLTWH(w * 0.63, h * 0.33, w * 0.12, h * 0.14));

      // 4本足
      for (final dx in [0.24, 0.36, 0.52, 0.60]) {
        p.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * dx, h * 0.62, w * 0.08, h * 0.18),
          const Radius.circular(3),
        ));
      }
    }

    // 耳（差分が最重要）
    _drawEars(p, Offset(w * 0.50, h * 0.20), w * 0.11, cfg.ears);

    // センザンコウの鱗（短いストロークで鱗感を表現）
    if (cfg.unique == UniqueFeature.scales) {
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 4; col++) {
          p.addOval(Rect.fromLTWH(
            w * (0.22 + col * 0.12),
            h * (0.37 + row * 0.08),
            w * 0.10, h * 0.06,
          ));
        }
      }
    }

    // ツチブタの長い鼻
    if (cfg.unique == UniqueFeature.longSnout) {
      p.addOval(Rect.fromLTWH(w * 0.80, h * 0.28, w * 0.14, h * 0.08));
    }

    // 尾
    _drawTail(p, Offset(w * 0.20, h * 0.48), cfg.tail, w, h, isSmall: true);
  }

  // ── Base 6: 鳥類型 ───────────────────────────────────

  void _drawAvian(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    final isFlamingoType = cfg.unique == UniqueFeature.curvedNeck;

    // 胴体（卵型）
    p.addOval(Rect.fromLTWH(w * 0.30, h * 0.35, w * 0.40, h * 0.35));

    // 首と頭（フラミンゴは S字カーブ）
    if (isFlamingoType) {
      final neckPath = Path()
        ..moveTo(w * 0.55, h * 0.38)
        ..quadraticBezierTo(w * 0.75, h * 0.25, w * 0.60, h * 0.15)
        ..lineTo(w * 0.65, h * 0.15)
        ..quadraticBezierTo(w * 0.80, h * 0.25, w * 0.60, h * 0.38)
        ..close();
      p.addPath(neckPath, Offset.zero);
      // 頭
      p.addOval(Rect.fromCenter(
        center: Offset(w * 0.62, h * 0.12),
        width: w * 0.14, height: w * 0.12,
      ));
      // 曲がったくちばし
      p.addOval(Rect.fromLTWH(w * 0.63, h * 0.14, w * 0.12, h * 0.05));
    }

    // 細長い脚
    final legH = isFlamingoType ? h * 0.38 : h * 0.28;
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.68, w * 0.05, legH),
      const Radius.circular(2),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.53, h * 0.68, w * 0.05, legH),
      const Radius.circular(2),
    ));

    // 尾羽
    if (cfg.tail == TailType.tailFan) {
      p.addOval(Rect.fromLTWH(w * 0.28, h * 0.44, w * 0.10, h * 0.18));
    }
  }

  // ── Base 7: 爬虫類型 ──────────────────────────────────

  void _drawReptile(Path p, Size s, SilhouetteConfig cfg) {
    final w = s.width;
    final h = s.height;

    // 胴体（平たく横長）
    p.addOval(Rect.fromLTWH(w * 0.15, h * 0.42, w * 0.55, h * 0.22));

    // 頭（平たい三角形に近い）
    p.moveTo(w * 0.68, h * 0.44);
    p.lineTo(w * 0.88, h * 0.50);
    p.lineTo(w * 0.68, h * 0.56);
    p.close();

    // 首
    p.addRect(Rect.fromLTWH(w * 0.62, h * 0.46, w * 0.08, h * 0.10));

    // 4本の短い足
    _drawLeg(p, Offset(w * 0.20, h * 0.58), w * 0.08, h * 0.16);
    _drawLeg(p, Offset(w * 0.36, h * 0.60), w * 0.08, h * 0.16);
    _drawLeg(p, Offset(w * 0.50, h * 0.58), w * 0.08, h * 0.16);
    _drawLeg(p, Offset(w * 0.22, h * 0.36), w * 0.08, h * 0.16, isFront: true);

    // 長い尾
    final tailPath = Path()
      ..moveTo(w * 0.15, h * 0.50)
      ..lineTo(w * 0.02, h * 0.52)
      ..lineTo(w * 0.02, h * 0.56)
      ..lineTo(w * 0.15, h * 0.54)
      ..close();
    p.addPath(tailPath, Offset.zero);
  }

  // ── 共通パーツ描画ヘルパー ─────────────────────────────

  void _drawEars(Path p, Offset headCenter, double headR, EarType type) {
    final cx = headCenter.dx;
    final cy = headCenter.dy;

    switch (type) {
      case EarType.none:
        break;
      case EarType.smallRound:
        p.addOval(Rect.fromCenter(center: Offset(cx - headR * 0.65, cy - headR * 0.70), width: headR * 0.55, height: headR * 0.55));
        p.addOval(Rect.fromCenter(center: Offset(cx + headR * 0.65, cy - headR * 0.70), width: headR * 0.55, height: headR * 0.55));
      case EarType.mediumRound:
        p.addOval(Rect.fromCenter(center: Offset(cx - headR * 0.65, cy - headR * 0.75), width: headR * 0.70, height: headR * 0.70));
        p.addOval(Rect.fromCenter(center: Offset(cx + headR * 0.65, cy - headR * 0.75), width: headR * 0.70, height: headR * 0.70));
      case EarType.pointedSmall:
        _drawPointedEar(p, Offset(cx - headR * 0.55, cy - headR * 0.65), headR * 0.40);
        _drawPointedEar(p, Offset(cx + headR * 0.55, cy - headR * 0.65), headR * 0.40);
      case EarType.pointedLarge:
        _drawPointedEar(p, Offset(cx - headR * 0.55, cy - headR * 0.75), headR * 0.65);
        _drawPointedEar(p, Offset(cx + headR * 0.55, cy - headR * 0.75), headR * 0.65);
      case EarType.fanLarge:
        // ゾウの大きな扇形の耳（横に広い）
        p.addOval(Rect.fromCenter(center: Offset(cx - headR * 1.20, cy + headR * 0.20), width: headR * 1.20, height: headR * 1.80));
        p.addOval(Rect.fromCenter(center: Offset(cx + headR * 1.20, cy + headR * 0.20), width: headR * 1.20, height: headR * 1.80));
      case EarType.veryLarge:
        // フェネックの超大耳
        _drawPointedEar(p, Offset(cx - headR * 0.60, cy - headR * 0.80), headR * 1.20);
        _drawPointedEar(p, Offset(cx + headR * 0.60, cy - headR * 0.80), headR * 1.20);
      case EarType.rabbitLong:
        // ツチブタの長い耳
        _drawPointedEar(p, Offset(cx - headR * 0.45, cy - headR * 0.80), headR * 1.40);
        _drawPointedEar(p, Offset(cx + headR * 0.45, cy - headR * 0.80), headR * 1.40);
      case EarType.tufted:
        p.addOval(Rect.fromCenter(center: Offset(cx - headR * 0.60, cy - headR * 0.80), width: headR * 0.50, height: headR * 0.70));
        p.addOval(Rect.fromCenter(center: Offset(cx + headR * 0.60, cy - headR * 0.80), width: headR * 0.50, height: headR * 0.70));
    }
  }

  void _drawPointedEar(Path p, Offset tip, double size) {
    p.moveTo(tip.dx, tip.dy - size);
    p.lineTo(tip.dx - size * 0.45, tip.dy + size * 0.10);
    p.lineTo(tip.dx + size * 0.45, tip.dy + size * 0.10);
    p.close();
  }

  void _drawLeg(Path p, Offset top, double w, double h, {bool isFront = false}) {
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(top.dx, top.dy, w, h),
      const Radius.circular(3),
    ));
  }

  void _drawArm(Path p, Offset shoulder, double length, {required bool isLeft}) {
    final dx = isLeft ? -length * 0.3 : length * 0.3;
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(
        shoulder.dx - 4,
        shoulder.dy,
        8,
        length,
      ),
      const Radius.circular(4),
    ));
  }

  void _drawFelicTail(Path p, Offset base, TailType type, double w, double h) {
    final isFluffy = type == TailType.veryLongFluffy || type == TailType.mediumFluffy;
    final thickness = isFluffy ? 10.0 : 5.0;
    final tailPath = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx - w * 0.10, base.dy + h * 0.25, base.dx + w * 0.05, base.dy + h * 0.40)
      ..lineTo(base.dx + thickness, base.dy + h * 0.40)
      ..quadraticBezierTo(base.dx - w * 0.06, base.dy + h * 0.25, base.dx + thickness * 0.5, base.dy)
      ..close();
    p.addPath(tailPath, Offset.zero);
  }

  void _drawTail(Path p, Offset base, TailType type, double w, double h, {bool isSmall = false}) {
    if (type == TailType.none || type == TailType.stub || type == TailType.veryShort) return;

    final len = isSmall ? h * 0.30 : h * 0.40;
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(base.dx - 4, base.dy, 6, len),
      const Radius.circular(3),
    ));

    if (type == TailType.mediumFluffy || type == TailType.bushy || type == TailType.veryLongFluffy) {
      p.addOval(Rect.fromCenter(
        center: Offset(base.dx, base.dy + len),
        width: isSmall ? 18 : 24,
        height: isSmall ? 14 : 20,
      ));
    }
  }

  // ── フォールバック（未登録種） ────────────────────────

  void _drawFallback(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final p = Path();

    // 汎用4足動物シルエット
    p.addOval(Rect.fromLTWH(w * 0.18, h * 0.35, w * 0.50, h * 0.32));
    p.addOval(Rect.fromCenter(center: Offset(w * 0.76, h * 0.30), width: w * 0.28, height: w * 0.26));
    p.addRect(Rect.fromLTWH(w * 0.62, h * 0.32, w * 0.12, h * 0.16));
    for (final dx in [0.22, 0.36, 0.50, 0.62]) {
      p.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * dx, h * 0.64, w * 0.08, h * 0.22),
        const Radius.circular(3),
      ));
    }

    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.assetKey != assetKey || old.color != color;
}
