import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package_resolver.dart';

/// Checks for security advisories for packages using the OSV.dev API.
class AdvisoryChecker {
  final Client? _httpClient;

  AdvisoryChecker({Client? httpClient}) : _httpClient = httpClient;

  /// Checks for vulnerabilities for the given [packages] and
  /// [registryRepoCommits].
  ///
  /// Returns a map from package name to a list of vulnerability summaries.
  ///
  /// For each package, we check the lockfile to see if it was installed
  /// via git, and if so we will check based on that hash. Otherwise, we
  /// check using the pub ecosystem queries by name and version.
  Future<Map<String, List<String>>> checkAdvisories(
    List<ResolvedPackage> packages,
    String rootPath,
    Logger logger, {
    Map<String, String>? registryRepoCommits,
  }) async {
    final results = <String, List<String>>{};
    final queries = <Map<String, dynamic>>[];
    final packageNames = <String>[];

    /// Queries for all the registry repositories.
    if (registryRepoCommits != null) {
      for (final entry in registryRepoCommits.entries) {
        packageNames.add(entry.key);
        queries.add({'commit': entry.value});
      }
    }

    // Queries for all the git and hosted packages.
    final lockFileCommits = await _readCommitsFromLockFile(rootPath);
    for (final package in packages) {
      final commit = lockFileCommits[package.name];
      if (commit != null) {
        packageNames.add(package.name);
        queries.add({'commit': commit});
        continue;
      }

      final version = await _readPackageVersion(package.rootPath);
      if (version == null) continue;

      packageNames.add(package.name);
      queries.add({
        'package': {'name': package.name, 'ecosystem': 'Pub'},
        'version': version,
      });
    }

    if (queries.isEmpty) return results;

    try {
      final response = await (_httpClient?.post ?? post)(
          Uri.parse('https://api.osv.dev/v1/querybatch'),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          },
          body: jsonEncode({'queries': queries}));
      final data = jsonDecode(response.body) as Map<String, Object?>;
      if (response.statusCode != 200) {
        logger.warning('''
Error checking for security advisories:
StatusCode: ${response.statusCode} (${response.reasonPhrase})
Content:
$data
''');
        return results;
      }
      final resultsList = data['results'] as List<Object?>?;

      if (resultsList == null) return results;

      for (var i = 0; i < resultsList.length; i++) {
        final result = resultsList[i] as Map<String, Object?>;
        final vulns = result['vulns'] as List<Object?>?;
        if (vulns != null && vulns.isNotEmpty) {
          final packageName = packageNames[i];
          final summaries = <String>[];
          for (final vuln in vulns) {
            final vulnMap = vuln as Map<String, Object?>;
            final id = vulnMap['id'] as String;
            summaries.add('https://osv.dev/vulnerability/$id');
          }
          results[packageName] = summaries;
        }
      }
    } catch (e) {
      // Handle exception, maybe log it
      // For now, return empty results to not block installation on network error
    }

    return results;
  }

  Future<Map<String, String>> _readCommitsFromLockFile(String rootPath) async {
    final commits = <String, String>{};
    final lockFile = File(p.join(rootPath, 'pubspec.lock'));
    if (!await lockFile.exists()) return commits;

    try {
      final content = await lockFile.readAsString();
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) return commits;

      final packages = yaml['packages'];
      if (packages is! YamlMap) return commits;

      for (final entry in packages.entries) {
        final packageName = entry.key as String;
        final packageInfo = entry.value;
        if (packageInfo is! YamlMap) continue;

        final source = packageInfo['source'] as String?;
        if (source == 'git') {
          final description = packageInfo['description'];
          if (description is YamlMap) {
            final resolvedRef = description['resolved-ref'] as String?;
            if (resolvedRef != null) {
              commits[packageName] = resolvedRef;
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors parsing lockfile
    }

    return commits;
  }

  Future<String?> _readPackageVersion(String packagePath) async {
    final pubspecFile = File(p.join(packagePath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return null;
    try {
      final content = await pubspecFile.readAsString();
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) return null;
      return yaml['version'] as String?;
    } catch (e) {
      return null;
    }
  }
}
