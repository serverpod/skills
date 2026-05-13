import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../core/dialog_support.dart';
import '../core/registry_repos.dart';
import '../models/global_config.dart';
import '../models/skill_manifest.dart';

final _logger = Logger('Migration');

/// Runs all migrations.
Future<void> runMigrations(
    String rootPath, DialogSupport? dialogSupport) async {
  final manifestFile = File(SkillManifest.pathIn(rootPath));
  final manifest = await SkillManifest.loadOrEmpty(manifestFile);

  var updatedManifest =
      await maybeDoRegistryMigration(rootPath, manifest, dialogSupport);

  // All migrations finished, update the version to the latest if it isn't
  // already. We wait until the end to do this so all migrations see the
  // original version.
  if (manifest.version != SkillManifest.currentVersion) {
    updatedManifest = SkillManifest(
      version: SkillManifest.currentVersion,
      installations: updatedManifest.installations,
      registries: updatedManifest.registries,
    );
  }

  if (updatedManifest != manifest) {
    await updatedManifest.save(manifestFile);
  }
}

/// Migrates registries from local workspace to global config if version < 2.
Future<SkillManifest> maybeDoRegistryMigration(String rootPath,
    SkillManifest manifest, DialogSupport? dialogSupport) async {
  if (manifest.version >= 2) {
    return manifest;
  }

  final globalConfigPath = GlobalConfig.globalPath;
  final globalConfigFile = File(globalConfigPath);
  var globalConfig = await GlobalConfig.loadOrEmpty(globalConfigFile);

  final reposDirPath = registryReposPath(rootPath);
  final reposDir = Directory(reposDirPath);
  if (!await reposDir.exists()) {
    return manifest;
  }

  final existingRepos = <RegistryRepo>[];
  try {
    await for (final entity in reposDir.list()) {
      if (entity is Directory) {
        final owner = p.basename(entity.path);
        await for (final subEntity in entity.list()) {
          if (subEntity is Directory) {
            final name = p.basename(subEntity.path);

            existingRepos.add(RegistryRepo(
              owner: owner,
              name: name,
            ));
          }
        }
      }
    }
  } catch (e) {
    // Ignore errors listing directories.
  }

  final reposToMigrate = <RegistryRepo>[];
  for (final repo in existingRepos) {
    if (globalConfig.registries
        .any((r) => r.owner == repo.owner && r.name == repo.name)) {
      _logger.info(
          'Skipping migration for ${repo.owner}/${repo.name} as it is already '
          'in global config.');
      continue;
    }
    reposToMigrate.add(repo);
  }

  if (reposToMigrate.isEmpty) {
    return manifest;
  }

  var updatedManifest = manifest;

  if (dialogSupport case var dialogSupport?) {
    for (final repo in reposToMigrate) {
      final options = [
        'keep this installed globally',
        'keep this installed for this project',
        'remove this registry'
      ];
      final index = await dialogSupport.showSingleSelectDialog(
        options,
        title:
            'Found installed skill repository ${repo.owner}/${repo.name} during migration, would you like to:',
      );

      if (index != null) {
        if (index == 0) {
          globalConfig = globalConfig.withRegistry(repo);
        } else if (index == 1) {
          updatedManifest = updatedManifest.withRegistry(repo);
        } else if (index == 2) {
          // Remove this registry from disk
          final repoPath = p.join(reposDirPath, repo.owner, repo.name);
          final repoDir = Directory(repoPath);
          if (await repoDir.exists()) {
            await repoDir.delete(recursive: true);
            _logger.info(
                'Deleted local clone for ${repo.owner}/${repo.name} from disk.');

            // Clean up owner dir if empty
            final ownerDir = repoDir.parent;
            if (await ownerDir.exists() && (await ownerDir.list().isEmpty)) {
              await ownerDir.delete();
            }
          }
        }
      } else {
        throw Exception(
            'Migration cancelled by user for ${repo.owner}/${repo.name}');
      }
    }
    await globalConfig.save(globalConfigFile);
  } else {
    for (final repo in reposToMigrate) {
      updatedManifest = updatedManifest.withRegistry(repo);
      _logger.info(
          'Automatically kept ${repo.owner}/${repo.name} local (non-interactive).');
    }
  }

  return SkillManifest(
    version: manifest.version,
    installations: updatedManifest.installations,
    registries: updatedManifest.registries,
  );
}
