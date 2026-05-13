import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/dialog_support.dart';
import '../core/registry_repos.dart';
import '../models/global_config.dart';
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
        logger.info('  ${repo.owner}/${repo.name}');
      }
    }

    logger.info('\nLocal registries:');
    if (manifest.registries.isEmpty) {
      logger.info('  None');
    } else {
      for (final repo in manifest.registries) {
        logger.info('  ${repo.owner}/${repo.name}');
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
        if (!globalConfig.registries
            .any((r) => r.owner == repo.owner && r.name == repo.name)) {
          globalConfig = globalConfig.withRegistry(repo);
          logger.info('Added ${repo.owner}/${repo.name} to global registries.');
        } else {
          logger.info(
              'Registry ${repo.owner}/${repo.name} already exists in global config.');
        }
      }
      await globalConfig.save(globalConfigFile);
    } else {
      final workspace = await resolveWorkspace();
      var manifest = await loadManifest(workspace.rootPath);
      for (final repo in repos) {
        if (!manifest.registries
            .any((r) => r.owner == repo.owner && r.name == repo.name)) {
          manifest = manifest.withRegistry(repo);
          logger.info('Added ${repo.owner}/${repo.name} to local registries.');
        } else {
          logger.info(
              'Registry ${repo.owner}/${repo.name} already exists in local config.');
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
    var isGlobal = argResults?['global'] as bool?;

    final workspace = await resolveWorkspace();
    var manifest = await loadManifest(workspace.rootPath);
    final globalConfigPath = GlobalConfig.globalPath;
    final globalConfigFile = File(globalConfigPath);
    var globalConfig = await GlobalConfig.loadOrEmpty(globalConfigFile);

    if (rest.isEmpty) {
      if (dialogSupport case var dialogSupport?) {
        final options = <String>[];
        final repoMapping = <int, RegistryRepo>{};
        final locationMapping = <int, String>{};

        int index = 0;
        for (final r in globalConfig.registries) {
          options.add('${r.owner}/${r.name} (Global)');
          repoMapping[index] = r;
          locationMapping[index] = 'Global';
          index++;
        }
        for (final r in manifest.registries) {
          options.add('${r.owner}/${r.name} (Local)');
          repoMapping[index] = r;
          locationMapping[index] = 'Local';
          index++;
        }

        if (options.isEmpty) {
          logger.info('No registries configured.');
          return;
        }

        final selectedIndices = await dialogSupport.showMultiSelectDialog(
          options,
          title: 'Select registries to remove:',
        );
        if (selectedIndices != null && selectedIndices.isNotEmpty) {
          for (final i in selectedIndices) {
            final repo = repoMapping[i]!;
            final loc = locationMapping[i]!;
            if (loc == 'Global') {
              globalConfig = globalConfig.withoutRegistry(repo);
              logger.info(
                  'Removed ${repo.owner}/${repo.name} from global registries.');
            } else {
              manifest = manifest.withoutRegistry(repo);
              logger.info(
                  'Removed ${repo.owner}/${repo.name} from local registries.');
            }
          }
          await globalConfig.save(globalConfigFile);
          await manifest.save(manifestFile(workspace.rootPath));
          return;
        } else {
          logger.info('No registries selected for removal.');
          return;
        }
      } else {
        throw UsageException(
            'Must specify at least one registry to remove when running non-interactively.',
            usage);
      }
    }

    final repos = <RegistryRepo>[];
    for (final arg in rest) {
      repos.add(parseRegistryArg(arg, usage));
    }

    for (final repo in repos) {
      final inGlobal = globalConfig.registries
          .any((r) => r.owner == repo.owner && r.name == repo.name);
      final inLocal = manifest.registries
          .any((r) => r.owner == repo.owner && r.name == repo.name);

      if (isGlobal != null) {
        if (isGlobal) {
          if (inGlobal) {
            globalConfig = globalConfig.withoutRegistry(repo);
            logger.info(
                'Removed ${repo.owner}/${repo.name} from global registries.');
          } else {
            logger.info(
                'Registry ${repo.owner}/${repo.name} not found in global config.');
          }
        } else {
          if (inLocal) {
            manifest = manifest.withoutRegistry(repo);
            logger.info(
                'Removed ${repo.owner}/${repo.name} from local registries.');
          } else {
            logger.info(
                'Registry ${repo.owner}/${repo.name} not found in local config.');
          }
        }
        continue;
      }

      if (inGlobal && inLocal) {
        if (dialogSupport case var dialogSupport?) {
          final options = ['Global', 'Local', 'Both'];
          final index = await dialogSupport.showSingleSelectDialog(options,
              title:
                  'Remove ${repo.owner}/${repo.name} from global, local, or both?');
          if (index != null) {
            if (index == 0 || index == 2) {
              globalConfig = globalConfig.withoutRegistry(repo);
              logger.info(
                  'Removed ${repo.owner}/${repo.name} from global registries.');
            }
            if (index == 1 || index == 2) {
              manifest = manifest.withoutRegistry(repo);
              logger.info(
                  'Removed ${repo.owner}/${repo.name} from local registries.');
            }
          }
        } else {
          throw UsageException(
              'Registry ${repo.owner}/${repo.name} is in both global and local configs. Use --global to specify which to remove.',
              usage);
        }
      } else if (inGlobal) {
        globalConfig = globalConfig.withoutRegistry(repo);
        logger
            .info('Removed ${repo.owner}/${repo.name} from global registries.');
      } else if (inLocal) {
        manifest = manifest.withoutRegistry(repo);
        logger
            .info('Removed ${repo.owner}/${repo.name} from local registries.');
      } else {
        logger.info(
            'Registry ${repo.owner}/${repo.name} not found in any config.');
      }
    }

    await globalConfig.save(globalConfigFile);
    await manifest.save(manifestFile(workspace.rootPath));
  }
}

/// Parses a registry argument into a [RegistryRepo].
RegistryRepo parseRegistryArg(String arg, String usage) {
  String owner;
  String name;
  String? customCloneUrl;

  if (arg.contains('/') && !arg.contains(':')) {
    final parts = arg.split('/');
    if (parts.length != 2) {
      throw UsageException(
          'Invalid registry format: $arg. Expected <owner>/<repo> or a Git URI.',
          usage);
    }
    owner = parts[0];
    name = parts[1];
  } else {
    customCloneUrl = arg;
    final uri = Uri.tryParse(arg);
    if (uri != null && uri.pathSegments.length >= 2) {
      owner = uri.pathSegments[uri.pathSegments.length - 2];
      name = uri.pathSegments.last;
      if (name.endsWith('.git')) {
        name = name.substring(0, name.length - 4);
      }
    } else if (arg.startsWith('git@') && arg.contains(':')) {
      final parts = arg.split(':');
      if (parts.length == 2) {
        final pathParts = parts[1].split('/');
        if (pathParts.length >= 2) {
          owner = pathParts[pathParts.length - 2];
          name = pathParts.last;
          if (name.endsWith('.git')) {
            name = name.substring(0, name.length - 4);
          }
        } else {
          throw UsageException(
              'Could not parse owner and name from Git URI: $arg', usage);
        }
      } else {
        throw UsageException(
            'Could not parse owner and name from Git URI: $arg', usage);
      }
    } else {
      throw UsageException(
          'Could not parse owner and name from Git URI: $arg', usage);
    }
  }
  return RegistryRepo(owner: owner, name: name, customCloneUrl: customCloneUrl);
}
