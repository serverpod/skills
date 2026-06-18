import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/core/constants.dart';
import 'package:yaml/yaml.dart';

import 'package_resolver.dart';

/// A skill found within a package's skills/ directory.
class ScannedSkill {
  final String packageName;
  final String skillPath;
  final String? registryUrl;
  final bool isGlobal;
  final SkillFrontmatter frontmatter;

  /// The basename of the [skillPath].
  String get basename => p.basename(skillPath);

  const ScannedSkill({
    required this.packageName,
    required this.skillPath,
    required this.frontmatter,
    this.registryUrl,
    this.isGlobal = false,
  });
}

/// Scans resolved packages for skills/ directories containing Agent Skills.
class SkillScanner {
  final Logger logger;

  SkillScanner(this.logger);

  /// Scans all [packages] for skills directories and returns found skills.
  Future<List<ScannedSkill>> scan(List<ResolvedPackage> packages) async {
    final skills = <ScannedSkill>[];

    for (final package in packages) {
      final packageSkills = await scanPackage(package);
      skills.addAll(packageSkills);
    }

    return skills;
  }

  /// Scans a single [package] for its skills/ directory.
  ///
  /// Only includes skills whose directory name starts with the package name
  /// followed by a hyphen (e.g., package `serverpod` must have skills named
  /// `serverpod-*`). Skills that don't match are skipped with a warning.
  Future<List<ScannedSkill>> scanPackage(ResolvedPackage package) async {
    final skillsDir = Directory(p.join(package.rootPath, 'skills'));
    if (!await skillsDir.exists()) return [];

    final prefix = '${package.name}-';
    final skills = <ScannedSkill>[];

    await for (final entity in skillsDir.list()) {
      if (entity is! Directory) continue;

      final skillMdFile = File(p.join(entity.path, 'SKILL.md'));
      if (!await skillMdFile.exists()) continue;

      SkillFrontmatter? frontmatter;
      try {
        frontmatter = SkillFrontmatter.fromSkillContent(
          await skillMdFile.readAsString(),
        );
      } on FormatException catch (e) {
        logger.warning(
          'Skipping skill at path ${skillMdFile.path} due to formatting '
          'error: $e',
        );
        continue;
      }
      if (frontmatter.isInternal && !shouldInstallInternalSkills) continue;

      final basename = p.basename(skillMdFile.path);
      if (!basename.startsWith(prefix)) {
        logger.warning(
          'Skipping skill "$basename" in ${package.name} '
          '-- name must start with "${package.name}-"',
        );
        continue;
      }

      skills.add(
        ScannedSkill(
          packageName: package.name,
          skillPath: entity.path,
          frontmatter: frontmatter,
        ),
      );
    }

    return skills;
  }
}

/// Parsed frontmatter from the skill file.
class SkillFrontmatter {
  /// The parsed metadata.internal field, defaults to false.
  final bool isInternal;

  /// The parsed name.
  final String name;

  SkillFrontmatter(this.name, {required this.isInternal});

  /// Extracts values from a parsed skill frontmatter [YamlDocument].
  factory SkillFrontmatter.fromYaml(YamlDocument document) {
    final mapContent = document.contents;
    if (mapContent is! YamlMap) {
      throw FormatException(
        'Expected a yaml map in the skill frontmatter',
        mapContent,
      );
    }
    final String name;
    if (mapContent['name'] case String parsedName) {
      name = parsedName;
    } else {
      throw FormatException('Expected a String name property', mapContent);
    }

    final YamlMap? metadata;
    if (mapContent['metadata'] case YamlMap? parsedMetadata) {
      metadata = parsedMetadata;
    } else {
      throw FormatException(
        'Expected a YamlMap or empty metadata property',
        mapContent,
      );
    }

    final bool isInternal;
    if (metadata?['internal'] case final bool parsedInternal) {
      isInternal = parsedInternal;
    } else {
      isInternal = false;
    }

    return SkillFrontmatter(name, isInternal: isInternal);
  }

  /// Parses the [SkillFrontmatter] from the full skill file content.
  factory SkillFrontmatter.fromSkillContent(String content, {Uri? sourceUri}) {
    if (!content.startsWith('---')) {
      throw FormatException('Skill must start with `---` frontmatter', content);
    }
    final frontMatterEnd = content.substring(3).indexOf('---');
    if (frontMatterEnd == -1) {
      throw FormatException(
        'Skill must have front matter ending delimiter ---',
        content,
      );
    }
    final yamlContent = content.substring(3, frontMatterEnd + 3);
    return SkillFrontmatter.fromYaml(
      loadYamlDocument(yamlContent, sourceUrl: sourceUri),
    );
  }
}
