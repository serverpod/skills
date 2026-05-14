import 'package:path/path.dart' as p;

import '../models/skill_manifest.dart';

/// How skill directories are organized inside a registry repo's `skills/` folder.
enum RegistrySkillLayout {
  /// Skills are directly under `skills/`; each dir name is `<package>-<suffix>`
  /// (e.g. `skills/shadcn_ui-buttons`).
  flat,

  /// Skills are grouped by package: `skills/<package>/<skill-dir>/`
  /// (e.g. `skills/riverpod/riverpod-get-started`).
  groupedByPackage,
}

/// A registry repository with a clone URL.
class RegistryRepo {
  final String cloneUrl;

  const RegistryRepo({
    required this.cloneUrl,
  });

  factory RegistryRepo.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('cloneUrl')) {
      return RegistryRepo(cloneUrl: json['cloneUrl'] as String);
    } else {
      final owner = json['owner'] as String;
      final name = json['name'] as String;
      final customCloneUrl = json['customCloneUrl'] as String?;
      final url = customCloneUrl ?? 'https://github.com/$owner/$name.git';
      return RegistryRepo(cloneUrl: url);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'cloneUrl': cloneUrl,
    };
  }

  /// The path segment for this repo under [reposDir].
  String get pathSegment => Uri.encodeComponent(cloneUrl);
}

/// Returns the absolute path to the repos root under [rootPath]:
/// `<rootPath>/.dart_skills/repos`.
String registryReposPath(String rootPath) {
  return p.join(rootPath, SkillManifest.dirName, 'repos');
}

/// Returns the absolute path where [repo] should be cloned under [rootPath]:
/// `<rootPath>/.dart_skills/repos/<owner>/<name>`.
String registryRepoPath(String rootPath, RegistryRepo repo) {
  return p.join(registryReposPath(rootPath), repo.pathSegment);
}
