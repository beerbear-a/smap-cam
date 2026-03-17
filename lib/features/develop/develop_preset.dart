enum DevelopPreset {
  standard,
  premium,
}

extension DevelopPresetLabel on DevelopPreset {
  String get label {
    switch (this) {
      case DevelopPreset.standard:
        return 'Standard';
      case DevelopPreset.premium:
        return 'Premium';
    }
  }

  String get subtitle {
    switch (this) {
      case DevelopPreset.standard:
        return '自然な粒状感と色のまとまり';
      case DevelopPreset.premium:
        return '粒状感と周辺光量、色の深みを強化';
    }
  }
}
