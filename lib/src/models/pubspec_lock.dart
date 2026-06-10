import 'dart:io';

import 'package:yaml/yaml.dart';

extension type PubspecLock(YamlMap source) {
  static Future<PubspecLock> fromFile(File file) async {
    final content = await file.readAsString();
    final yaml = loadYaml(content);
    if (yaml is YamlMap) {
      return PubspecLock(yaml);
    } else {
      throw FormatException(
          'Error parsing ${file.uri}: Expected a YamlMap but got '
          '${yaml.runtimeType}');
    }
  }

  PubspecLockPackages get packages {
    final packagesYaml = source['packages'];
    if (packagesYaml is! YamlMap) {
      throw FormatException('Expected `packages` key to be a YamlMap but got a '
          '${packagesYaml.runtimeType}]}');
    }
    return PubspecLockPackages(packagesYaml);
  }
}

extension type PubspecLockPackages(YamlMap source) {
  Iterable<MapEntry<String, PubspecLockPackage>> get entries =>
      source.keys.map((key) =>
          MapEntry(key as String, PubspecLockPackage(source[key] as YamlMap)));

  PubspecLockPackage? operator [](String key) {
    final val = source[key];
    if (val is YamlMap) return PubspecLockPackage(val);
    return null;
  }
}

extension type PubspecLockPackage(YamlMap source) {
  bool get isTransitiveDependency => !const {'direct main', 'direct dev'}
      .contains(source['dependency'] as String);
}
