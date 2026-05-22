import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:skills/src/commands/skills_command.dart';
import 'package:skills/src/core/git_runner.dart';
import 'package:skills/src/core/package_resolver.dart';
import 'package:skills/src/core/pub_runner.dart';
import 'package:skills/src/core/registry_scanner.dart';
import 'package:skills/src/core/registry_sync.dart';
import 'package:skills/src/core/skill_installer.dart';
import 'package:skills/src/core/skill_merger.dart';
import 'package:skills/src/core/skill_scanner.dart';
import 'package:skills/src/core/workspace_resolver.dart';
import 'package:skills/src/ide/ide.dart';
import 'package:skills/src/core/dialog_support.dart';
import 'package:skills/src/models/global_config.dart';

import '../models/skill_manifest.dart';

/// Installs skills from package dependencies for [ides].
Future<bool> getSkills({
  required List<Ide> ides,
  required Logger logger,
  required WorkspaceLayout workspace,
  DialogSupport? dialogSupport,
  GitRunner gitRunner = const GitRunner(),
  String usage = '',
  String? packageName,
}) async {
  final ready = await PubRunner.ensureWorkspaceConfigs(workspace);
  if (!ready) {
    throw UsageException('Failed to run pub get.', usage);
  }

  final packages = await PackageResolver.resolveWorkspace(
    workspace,
    packageName: packageName,
  );

  if (packageName != null && packages.isEmpty) {
    logger.severe('Package "$packageName" not found in dependencies.');
    return false;
  }

  final scanner = SkillScanner(logger);
  final dartSkills = await scanner.scan(packages);
  final rootPath = workspace.rootPath;
  var manifest = await SkillManifest.loadOrEmptyFromRoot(rootPath);

  final globalConfigPath = GlobalConfig.globalPath;
  final globalConfigFile = File(globalConfigPath);
  var globalConfig = await GlobalConfig.loadOrEmpty(globalConfigFile);

  final registrySkills = <ScannedSkill>[];
  if (await gitRunner.isAvailable) {
    final registrySync = RegistrySync(
        repos: [...globalConfig.registries, ...manifest.registries]);
    await registrySync.sync(rootPath, onProgress: logger.info);

    final registryScanner = RegistryScanner();
    registrySkills.addAll(await registryScanner.scan(
      rootPath,
      isGlobal: true,
      repos: globalConfig.registries,
    ));
    registrySkills.addAll(await registryScanner.scan(
      rootPath,
      isGlobal: false,
      repos: manifest.registries,
    ));
  } else {
    logger.warning(
      'Warning: git not found. Skipping GitHub registry skills.',
    );
  }

  final resolvedPackageNames = packages.map((p) => p.name).toSet();
  final skills = mergeSkills(
    dartSkills: dartSkills,
    registrySkills: registrySkills,
    resolvedPackageNames: resolvedPackageNames,
  );

  if (skills.isEmpty) {
    logger.info('No skills found in ${packageName ?? "any"} packages.');
    return false;
  }

  final installer = SkillInstaller(dialogSupport);

  for (final ide in ides) {
    final result = await installer.installSkillsForIde(
      ide: ide,
      rootPath: rootPath,
      skills: skills,
      manifest: manifest,
      globalConfig: globalConfig,
    );
    if (result == null) {
      logger.warning('Installation aborted for IDE ${ide.cliName}');
      continue;
    }
    manifest = result.manifest;
    globalConfig = result.globalConfig;
    for (final info in result.installed) {
      logger.info('  [${info.ideName}] Installed ${info.skillName}');
    }
  }

  await globalConfig.save(globalConfigFile);
  await manifest.save(manifestFile(rootPath));

  final ideNames = ides.map((e) => e.cliName).join(', ');
  logger.info('Installed ${skills.length} skill(s) for $ideNames.');

  return true;
}
