import 'dart:io';

import 'package:settings_yaml/settings_yaml.dart';

class Config {
  static String _refinerDataStoreDirectory = '';

  static String get refinerDataStoreDirectory {
    return _refinerDataStoreDirectory;
  }

  static void load() {
    final settings = SettingsYaml.load(
        pathToSettings: '${Directory.current.path}/config.yaml');

    _refinerDataStoreDirectory =
        settings['refiner_data_store_directory'] as String;
  }
}
