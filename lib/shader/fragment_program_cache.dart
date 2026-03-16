import 'dart:ui' as ui;

final Map<String, ui.FragmentProgram> _programCache =
    <String, ui.FragmentProgram>{};
final Map<String, Future<ui.FragmentProgram>> _programFutures =
    <String, Future<ui.FragmentProgram>>{};

Future<ui.FragmentProgram> loadFragmentProgram(String asset) {
  if (_programCache.containsKey(asset)) {
    return Future.value(_programCache[asset]!);
  }
  _programFutures[asset] ??= ui.FragmentProgram.fromAsset(asset).then((p) {
    _programCache[asset] = p;
    return p;
  }).catchError((Object error) {
    _programFutures.remove(asset);
    throw error;
  });
  return _programFutures[asset]!;
}
