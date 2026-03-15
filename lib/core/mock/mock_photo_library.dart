import 'dart:io';
import 'dart:math';

const mockPhotoPaths = <String>[
  '/Users/aritashinichi/Documents/名称未設定フォルダ/IMG_6510.JPG',
  '/Users/aritashinichi/Documents/名称未設定フォルダ/DSC04101.JPG',
  '/Users/aritashinichi/Documents/名称未設定フォルダ/DSC04713.JPG',
  '/Users/aritashinichi/Documents/名称未設定フォルダ/DSC04780.JPG',
  '/Users/aritashinichi/Documents/名称未設定フォルダ/IMG_2419.jpeg',
];

final Random _mockPhotoRandom = Random();

List<String> availableMockPhotoPaths() {
  return mockPhotoPaths.where((path) => File(path).existsSync()).toList();
}

String? primaryMockPhotoPath() {
  final available = availableMockPhotoPaths();
  if (available.isNotEmpty) return available.first;
  return mockPhotoPaths.isEmpty ? null : mockPhotoPaths.first;
}

String? pickRandomMockPhotoPath({String? excluding}) {
  final available = availableMockPhotoPaths();
  if (available.isEmpty) return primaryMockPhotoPath();

  final candidates = excluding == null
      ? available
      : available.where((path) => path != excluding).toList();
  final pool = candidates.isEmpty ? available : candidates;
  return pool[_mockPhotoRandom.nextInt(pool.length)];
}
