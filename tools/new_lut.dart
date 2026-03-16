// tools/new_lut.dart — LUT シェーダー スキャフォールドツール
//
// 使い方:
//   dart run tools/new_lut.dart <id> <LABEL> "<subtitle>" [--free|--pro]
//
// 例:
//   dart run tools/new_lut.dart cinestill800t CINE "CineStill 800T" --pro
//   dart run tools/new_lut.dart portra400 PORTRA "Kodak Portra 400" --pro
//
// 生成・更新されるファイル:
//   shaders/film_{id}.frag       (テンプレートから生成)
//   pubspec.yaml                 (shaders: に追加)
//   lib/features/camera/widgets/film_preview.dart  (LutType に追加)

import 'dart:io';

// ── カラーコード ─────────────────────────────────────────
const _reset = '\x1B[0m';
const _bold  = '\x1B[1m';
const _green = '\x1B[32m';
const _cyan  = '\x1B[36m';
const _yellow= '\x1B[33m';
const _red   = '\x1B[31m';

void ok(String msg)   => print('$_green  ✓$_reset $msg');
void info(String msg) => print('$_cyan  →$_reset $msg');
void warn(String msg) => print('$_yellow  ⚠$_reset $msg');
void fail(String msg) { print('$_red  ✗$_reset $msg'); exit(1); }

// ─────────────────────────────────────────────────────────

void main(List<String> args) {
  // ── 引数パース ───────────────────────────────────────
  if (args.length < 3) {
    print('''
${_bold}使い方:${_reset}
  dart run tools/new_lut.dart <id> <LABEL> "<subtitle>" [--free|--pro]

${_bold}引数:${_reset}
  id        スネークケース識別子 (例: cinestill800t, portra400)
  LABEL     UIに表示される短いラベル (例: CINE, PORTRA)
  subtitle  フィルム名の説明文 (例: "CineStill 800T")
  --free    無料LUT (デフォルト: --pro)
  --pro     Pro専用LUT

${_bold}例:${_reset}
  dart run tools/new_lut.dart cinestill800t CINE "CineStill 800T" --pro
  dart run tools/new_lut.dart xpro2 XPRO "Fuji Velvia XPro" --free
''');
    exit(1);
  }

  final id       = args[0];
  final label    = args[1];
  final subtitle = args[2];
  final isPro    = !args.contains('--free');

  // 識別子バリデーション
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id)) {
    fail('id は小文字英数字とアンダースコアのみ使用できます: $id');
  }
  if (label.isEmpty || label.length > 8) {
    fail('LABEL は 1〜8 文字で指定してください: $label');
  }

  // プロジェクトルート確定
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final projectRoot = scriptDir.parent;

  print('\n${_bold}╔═ new_lut.dart — LUT スキャフォールド ══════════╗$_reset');
  print('${_bold}║$_reset  id:       $id');
  print('${_bold}║$_reset  label:    $label');
  print('${_bold}║$_reset  subtitle: $subtitle');
  print('${_bold}║$_reset  tier:     ${isPro ? "Pro 🔒" : "Free ✓"}');
  print('${_bold}╚════════════════════════════════════════════════╝$_reset\n');

  // ── 1. .frag ファイル生成 ────────────────────────────
  final fragFile = File('${projectRoot.path}/shaders/film_$id.frag');
  if (fragFile.existsSync()) {
    fail('shaders/film_$id.frag は既に存在します。別のidを使うか手動で削除してください。');
  }

  final templateFile = File('${projectRoot.path}/shaders/_template.frag');
  if (!templateFile.existsSync()) {
    fail('shaders/_template.frag が見つかりません。');
  }

  final fragContent = templateFile
      .readAsStringSync()
      .replaceAll('{{FILM_FILE}}', 'film_$id.frag')
      .replaceAll('{{FILM_LABEL}}', label)
      .replaceAll('{{FILM_SUBTITLE}}', subtitle);

  fragFile.writeAsStringSync(fragContent);
  ok('shaders/film_$id.frag を生成しました');

  // ── 2. pubspec.yaml ──────────────────────────────────
  final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
  final pubspecContent = pubspecFile.readAsStringSync();

  final shaderEntry = '    - shaders/film_$id.frag';
  if (pubspecContent.contains(shaderEntry)) {
    warn('pubspec.yaml に既に登録されています。スキップします。');
  } else {
    // 最後の shaders エントリの直後に挿入
    final linePattern = RegExp(r'    - shaders/film_\w+\.frag');
    final matches = linePattern.allMatches(pubspecContent).toList();
    if (matches.isEmpty) {
      fail('pubspec.yaml の shaders: セクションが見つかりません。手動で追加してください。');
    }
    final lastMatch = matches.last;
    final updated = pubspecContent.substring(0, lastMatch.end)
        + '\n$shaderEntry'
        + pubspecContent.substring(lastMatch.end);
    pubspecFile.writeAsStringSync(updated);
    ok('pubspec.yaml に shaders/film_$id.frag を追加しました');
  }

  // ── 3. film_preview.dart ─────────────────────────────
  final previewFile = File(
    '${projectRoot.path}/lib/features/camera/widgets/film_preview.dart',
  );
  var preview = previewFile.readAsStringSync();

  void insertBefore(String marker, String newCode) {
    if (!preview.contains(marker)) {
      warn('マーカー "$marker" が見つかりません。film_preview.dart を手動で更新してください。');
      return;
    }
    if (preview.contains('LutType.$id')) {
      warn('LutType.$id は既に存在します。$marker へのコード挿入をスキップします。');
      return;
    }
    preview = preview.replaceFirst(marker, '$newCode\n      $marker');
  }

  // [1] enum 値
  if (!preview.contains('  $id,') && !preview.contains('  $id;')) {
    const enumMarker = '  // {{LUT_ENUM}} ← new_lut.dart が自動挿入するマーカー (削除しない)';
    if (preview.contains(enumMarker)) {
      // mono; → mono, に変えて新しい値を追加
      preview = preview.replaceFirst(
        'mono;\n  $enumMarker',
        'mono,\n  $id;\n  $enumMarker',
      );
      ok('LutType.$id を enum に追加しました');
    } else {
      warn('{{LUT_ENUM}} マーカーが見つかりません。enum への追加を手動で行ってください。');
    }
  } else {
    warn('LutType.$id は既に enum に存在します。スキップします。');
  }

  // [2] label
  insertBefore(
    '// {{LUT_LABEL}}',
    '      case LutType.$id:\n        return \'$label\';',
  );
  ok('label switch に case $id を追加しました');

  // [3] subtitle
  insertBefore(
    '// {{LUT_SUBTITLE}}',
    "      case LutType.$id:\n        return '$subtitle';",
  );
  ok('subtitle switch に case $id を追加しました');

  // [4] isPro
  insertBefore(
    '// {{LUT_ISPRO}}',
    '      case LutType.$id:\n        return ${isPro ? 'true' : 'false'};',
  );
  ok('isPro switch に case $id を追加しました (${isPro ? "Pro" : "Free"})');

  // [5] colorMatrix (デフォルト: ニュートラル近似)
  final matrixComment = isPro
      ? '// TODO: $label の ColorFilter.matrix をチューニングする'
      : '// TODO: $label の ColorFilter.matrix をチューニングする (無料LUT)';
  insertBefore(
    '// {{LUT_COLORMATRIX}}',
    '''      // ── $label ($subtitle) ──────────────────────────────────────────────────
      $matrixComment
      case LutType.$id:
        return [
          1.02,  0.01,  0.00, 0,  8, // R
          0.00,  1.00,  0.01, 0,  3, // G
          -0.01, 0.00,  0.95, 0, -5, // B
          0,     0,     0,    1,  0,
        ];''',
  );
  ok('colorMatrix switch に case $id を追加しました (要チューニング)');

  // [6] shaderParams (デフォルト: 中庸な値)
  insertBefore(
    '// {{LUT_SHADERPARAMS}}',
    '''      case LutType.$id:
        // TODO: $subtitle の GLSL パラメータをチューニングする
        // CUSTOMIZE セクション [1]〜[8] を参照
        return const FilmShaderParams(
          warmth: 0.70,
          saturation: 1.00,
          shadowLift: 0.50,
          highlightRolloff: 0.65,
          grainAmount: 0.80,
          vignetteStrength: 0.55,
          halationStrength: 0.50,
          softness: 0.40,
          chromaticAberration: 0.35,
          milkyHighlights: 0.50,
          contrast: 0.00,
          blueCrush: 0.10,
          halationWarmth: 0.60,
          grainSize: 1.8,
        );''',
  );
  ok('shaderParams switch に case $id を追加しました (要チューニング)');

  // [7] shaderAsset
  insertBefore(
    '// {{LUT_SHADERASSET}}',
    "      case LutType.$id:\n        return 'shaders/film_$id.frag'; // $subtitle",
  );
  ok('shaderAsset switch に case $id を追加しました');

  // [8] vignetteStrength
  insertBefore(
    '// {{LUT_VIGNETTE}}',
    '      case LutType.$id:\n        return 0.55; // TODO: $subtitle のビネット強度',
  );
  ok('vignetteStrength switch に case $id を追加しました');

  previewFile.writeAsStringSync(preview);

  // ── 完了メッセージ ───────────────────────────────────
  print('''
${_bold}
╔═ 完了！次にすること ══════════════════════════════╗$_reset

  ${_bold}[Step 1] GLSL を調整する$_reset
  ${_cyan}shaders/film_$id.frag${_reset}
  CUSTOMIZE [1]〜[8] セクションを順番に調整。
  参考: ${isPro ? 'shaders/film_fuji400.frag や film_mono_hp5.frag' : 'shaders/film_iso800.frag'}

  ${_bold}[Step 2] ColorFilter.matrix を調整する$_reset
  ${_cyan}lib/features/camera/widgets/film_preview.dart${_reset}
  LutType.$id の colorMatrix を実写画像で確認しながら調整。
  ライブプレビュー用なので bias (5列目) に注意。

  ${_bold}[Step 3] FilmShaderParams を調整する$_reset
  同ファイルの LutType.$id の shaderParams。
  現像・アルバム画面での静止画品質に直結。

  ${_bold}[Step 4] analyze で確認する$_reset
  ${_cyan}flutter analyze${_reset}
  exhaustive switch に漏れがあれば Dart が教えてくれる。

  ${_bold}[Step 5] シミュレーターで確認する$_reset
  ${_cyan}flutter run${_reset} → LUTセレクターで $label を選択

${_bold}╚══════════════════════════════════════════════════╝$_reset
''');
}
