import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapCacheManager {
  static final MapCacheManager _instance = MapCacheManager._internal();
  factory MapCacheManager() => _instance;
  MapCacheManager._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> syncMaps() async {
    try {
      final ref = _storage.ref('maps/manifest.json');
      final bytes = await ref.getData();
      if (bytes == null) return;

      final String content = utf8.decode(bytes);
      final Map<String, dynamic> manifest = json.decode(content);
      final Map<String, dynamic> files = manifest['files'];

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      for (String mapKey in files.keys) {
        Map<String, dynamic> fileData = files[mapKey];
        int remoteVersion = fileData['v'];
        String fileName = fileData['file_name'];

        int localVersion = prefs.getInt('map_v_$mapKey') ?? 0;

        File localFile = await _getLocalFile(fileName);
        bool exists = await localFile.exists();

        if (remoteVersion > localVersion || !exists) {
          print("Update detected for $mapKey. Downloading...");
          await _downloadMap(mapKey, fileName, remoteVersion);
        }
      }
    } catch (e) {
      print("Map Sync Error: $e");
    }
  }

  Future<bool> areAllMapsDownloaded() async {
    try {
      final ref = _storage.ref('maps/manifest.json');
      final bytes = await ref.getData();
      if (bytes == null) return false;

      final Map<String, dynamic> manifest = json.decode(utf8.decode(bytes));
      final Map<String, dynamic> files = manifest['files'];

      for (var fileData in files.values) {
        File file = await _getLocalFile(fileData['file_name']);
        if (!await file.exists()) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _downloadMap(String mapKey, String fileName, int version) async {
    try {
      File localFile = await _getLocalFile(fileName);

      if (!localFile.parent.existsSync()) {
        localFile.parent.createSync(recursive: true);
      }

      await _storage.ref('maps/$fileName').writeToFile(localFile);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('map_v_$mapKey', version);

      print("Map $fileName updated to version $version");
    } catch (e) {
      print("Failed to download $fileName: $e");
    }
  }

  Future<File> _getLocalFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/map_cache/$fileName');
  }

  Future<File?> getMapFile(String fileName) async {
    File file = await _getLocalFile(fileName);
    if (await file.exists()) {
      return file;
    }
    return null; 
  }
}
