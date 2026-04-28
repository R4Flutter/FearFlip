import 'package:flutter/services.dart';

class AssetManager {
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  Future<Uint8List> loadBinary(String path) async {
    final cached = _cache[path];
    if (cached != null) {
      return cached;
    }

    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    _cache[path] = bytes;
    return bytes;
  }

  void release(String path) {
    _cache.remove(path);
  }

  void clear() {
    _cache.clear();
  }
}
