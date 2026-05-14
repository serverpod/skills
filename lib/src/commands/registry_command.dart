import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/dialog_support.dart';
import '../core/registry_repos.dart';
import '../models/global_config.dart';
import '../models/skill_manifest.dart';
import 'skills_command.dart';

/// Command to manage skill registries.
class RegistryCommand extends Command<void> {
  @override
  final String name = 'registry';

  @override
  final String description = 'Manage skill registries.';

  RegistryCommand({DialogSupport? dialogSupport}) {
    addSubcommand(RegistryListCommand());
    addSubcommand(RegistryAddCommand(dialogSupport: dialogSupport));
    addSubcommand(RegistryRemoveCommand(dialogSupport: dialogSupport));
  }
}

/// Subcommand to list registries.
class RegistryListCommand extends SkillsCommand {
  @override
  final String name = 'list';

  @override
  final String description = 'List configured registries.';

  @override
  Future<void> run() async {
    final workspace = await resolveWorkspace();
    final manifest = await loadManifest(workspace.rootPath);

    final globalConfigPath = GlobalConfig.globalPath;
    final globalConfig = await GlobalConfig.loadOrEmpty(File(globalConfigPath));

    logger.info('Global registries:');
    if (globalConfig.registries.isEmpty) {
      logger.info('  None');
    } else {
      for (final repo in globalConfig.registries) {
        logger.info('  ${repo.cloneUrl}');
      }
    }

    logger.info('\nLocal registries:');
    if (manifest.registries.isEmpty) {
      logger.info('  None');
    } else {
      for (final repo in manifest.registries) {
        logger.info('  ${repo.cloneUrl}');
      }
    }
  }
}

/// Subcommand to add a registry.
class RegistryAddCommand extends SkillsCommand {
  @override
  final String name = 'add';

  @override
  final String description = 'Add a new registry.';

  final DialogSupport? dialogSupport;

  RegistryAddCommand({this.dialogSupport}) {
    argParser.addFlag('global',
        help: 'Add to global config.', defaultsTo: null);
  }

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      throw UsageException('Must specify at least one registry to add.', usage);
    }

    var isGlobal = argResults?['global'] as bool?;

    if (isGlobal == null) {
      if (dialogSupport case var dialogSupport?) {
        final index = await dialogSupport.showSingleSelectDialog(
            ['Global', 'Local'],
            title: 'Install globally or locally?');
        if (index != null) {
          isGlobal = index == 0;
        }
      }
    }

    if (isGlobal == null) {
      throw UsageException(
          'Must specify whether to install globally or locally.', usage);
    }

    final repos = <RegistryRepo>[];
    for (final arg in rest) {
      repos.add(parseRegistryArg(arg, usage));
    }

    if (isGlobal) {
      final globalConfigPath = GlobalConfig.globalPath;
      final globalConfigFile = File(globalConfigPath);
      var globalConfig = await GlobalConfig.loadOrEmpty(globalConfigFile);
      for (final repo in repos) {
        if (!globalConfig.registries.any((r) => r.cloneUrl == repo.cloneUrl)) {
          globalConfig = globalConfig.withRegistry(repo);
          logger.info('Added ${repo.cloneUrl} to global registries.');
        } else {
          logger.info(
              'Registry ${repo.cloneUrl} already exists in global config.');
        }
      }
      await globalConfig.save(globalConfigFile);
    } else {
      final workspace = await resolveWorkspace();
      var manifest = await loadManifest(workspace.rootPath);
      for (final repo in repos) {
        if (!manifest.registries.any((r) => r.cloneUrl == repo.cloneUrl)) {
          manifest = manifest.withRegistry(repo);
          logger.info('Added ${repo.cloneUrl} to local registries.');
        } else {
          logger.info(
              'Registry ${repo.cloneUrl} already exists in local config.');
        }
      }
      await manifest.save(manifestFile(workspace.rootPath));
    }
  }
}

/// Subcommand to remove a registry.
class RegistryRemoveCommand extends SkillsCommand {
  @override
  final String name = 'remove';

  @override
  final String description = 'Remove a registry.';

  final DialogSupport? dialogSupport;

  RegistryRemoveCommand({this.dialogSupport}) {
    argParser.addFlag('global',
        help: 'Remove from global config.', defaultsTo: null);
  }

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    final isGlobal = argResults?['global'] as bool?;

    final workspace = await resolveWorkspace();
    final manifest = await loadManifest(workspace.rootPath);
    final globalConfigPath = GlobalConfig.globalPath;
    final globalConfigFile = File(globalConfigPath);
    final globalConfig = await GlobalConfig.loadOrEmpty(globalConfigFile);

    if (rest.isEmpty) {
      await _interactiveRemove(
          globalConfig, manifest, globalConfigFile, workspace.rootPath);
    } else {
      await _removeByArgs(rest, isGlobal, globalConfig, manifest,
          globalConfigFile, workspace.rootPath);
    }
  }

  Future<void> _interactiveRemove(GlobalConfig globalConfig,
      SkillManifest manifest, File globalConfigFile, String rootPath) async {
    if (dialogSupport case var dialogSupport?) {
      final options = <String>[];
      final repoMapping = <int, RegistryRepo>{};
      final locationMapping = <int, String>{};

      int index = 0;
      for (final r in globalConfig.registries) {
        options.add('${r.cloneUrl} (Global)');
        repoMapping[index] = r;
        locationMapping[index] = 'Global';
        index++;
      }
      for (final r in manifest.registries) {
        options.add('${r.cloneUrl} (Local)');
        repoMapping[index] = r;
        locationMapping[index] = 'Local';
        index++;
      }

      if (options.isEmpty) {
        logger.info('No registries configured.');
      } else {
        final selectedIndices = await dialogSupport.showMultiSelectDialog(
          options,
          title: 'Select registries to remove:',
        );

        if (selectedIndices != null && selectedIndices.isNotEmpty) {
          var updatedGlobalConfig = globalConfig;
          var updatedManifest = manifest;

          for (final i in selectedIndices) {
            final repo = repoMapping[i]!;
            final loc = locationMapping[i]!;
            if (loc == 'Global') {
              updatedGlobalConfig = updatedGlobalConfig.withoutRegistry(repo);
              logger.info('Removed ${repo.cloneUrl} from global registries.');
            } else {
              updatedManifest = updatedManifest.withoutRegistry(repo);
              logger.info('Removed ${repo.cloneUrl} from local registries.');
            }
          }
          await updatedGlobalConfig.save(globalConfigFile);
          await updatedManifest.save(manifestFile(rootPath));
        } else {
          logger.info('No registries selected for removal.');
        }
      }
    } else {
      throw UsageException(
          'Must specify at least one registry to remove when running non-interactively.',
          usage);
    }
  }

  Future<void> _removeByArgs(
      List<String> rest,
      bool? isGlobal,
      GlobalConfig globalConfig,
      SkillManifest manifest,
      File globalConfigFile,
      String rootPath) async {
    final repos = <RegistryRepo>[];
    for (final arg in rest) {
      repos.add(parseRegistryArg(arg, usage));
    }

    var updatedGlobalConfig = globalConfig;
    var updatedManifest = manifest;

    for (final repo in repos) {
      final inGlobal = updatedGlobalConfig.registries
          .any((r) => r.cloneUrl == repo.cloneUrl);
      final inLocal =
          updatedManifest.registries.any((r) => r.cloneUrl == repo.cloneUrl);

      if (isGlobal != null) {
        if (isGlobal) {
          if (inGlobal) {
            updatedGlobalConfig = updatedGlobalConfig.withoutRegistry(repo);
            logger.info('Removed ${repo.cloneUrl} from global registries.');
          } else {
            logger
                .info('Registry ${repo.cloneUrl} not found in global config.');
          }
        } else {
          if (inLocal) {
            updatedManifest = updatedManifest.withoutRegistry(repo);
            logger.info('Removed ${repo.cloneUrl} from local registries.');
          } else {
            logger.info('Registry ${repo.cloneUrl} not found in local config.');
          }
        }
      } else {
        if (inGlobal && inLocal) {
          if (dialogSupport case var dialogSupport?) {
            final options = ['Global', 'Local', 'Both'];
            final index = await dialogSupport.showSingleSelectDialog(options,
                title: 'Remove ${repo.cloneUrl} from global, local, or both?');
            if (index != null) {
              if (index == 0 || index == 2) {
                updatedGlobalConfig = updatedGlobalConfig.withoutRegistry(repo);
                logger.info('Removed ${repo.cloneUrl} from global registries.');
              }
              if (index == 1 || index == 2) {
                updatedManifest = updatedManifest.withoutRegistry(repo);
                logger.info('Removed ${repo.cloneUrl} from local registries.');
              }
            }
          } else {
            throw UsageException(
                'Registry ${repo.cloneUrl} is in both global and local configs. Use --global to specify which to remove.',
                usage);
          }
        } else if (inGlobal) {
          updatedGlobalConfig = updatedGlobalConfig.withoutRegistry(repo);
          logger.info('Removed ${repo.cloneUrl} from global registries.');
        } else if (inLocal) {
          updatedManifest = updatedManifest.withoutRegistry(repo);
          logger.info('Removed ${repo.cloneUrl} from local registries.');
        } else {
          logger.info('Registry ${repo.cloneUrl} not found in any config.');
        }
      }
    }

    await updatedGlobalConfig.save(globalConfigFile);
    await updatedManifest.save(manifestFile(rootPath));
  }
}

/// Parses a registry argument into a [RegistryRepo].
RegistryRepo parseRegistryArg(String arg, String usage) {
  if (arg.contains('/') && !arg.contains(':') && !arg.contains('@')) {
    final parts = arg.split('/');
    if (parts.length != 2) {
      throw UsageException(
          'Invalid registry format: $arg. Expected <owner>/<repo> or a Git URI.',
          usage);
    }
    final url = 'https://github.com/${parts[0]}/${parts[1]}.git';
    return RegistryRepo(cloneUrl: url);
  } else {
    return RegistryRepo(cloneUrl: arg);
  }
}
