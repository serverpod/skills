import 'dart:io';

import 'package:yaml/yaml.dart';

/// Typed wrapper for pubspec.lock files.
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

/// Typed wrapper for pubspec.lock 'packages' map.
extension type PubspecLockPackages(YamlMap source) {
  Iterable<MapEntry<String, PubspecLockPackage>> get entries =>
      source.keys.map((Object? key) {
        if (key is! String) {
          throw FormatException(
              'Expected only String keys for `packages` but got an '
              '${key.runtimeType}');
        }
        return MapEntry(key, this[key]!);
      });

  PubspecLockPackage? operator [](String key) {
    final val = source[key] as Object?;
    if (val == null) return null;
    if (val is! YamlMap) {
      throw FormatException(
          'Expected a YamlMap for `packages` entries but got an '
          '${val.runtimeType}');
    }
    return PubspecLockPackage(val);
  }
}

/// Typed wrapper for pubspec.lock package information (these are values of the
/// 'packages' map).
extension type PubspecLockPackage(YamlMap source) {
  bool get isTransitiveDependency =>
      !const {'direct main', 'direct dev'}.contains(dependency);

  String get dependency {
    final dependency = source['dependency'] as Object;
    if (dependency is! String) {
      throw FormatException(
          'Expected `dependency` value to be a String but got an '
          '${dependency.runtimeType}');
    }
    return dependency;
  }
}
