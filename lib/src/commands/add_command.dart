import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:skills/src/commands/get_skills.dart';

import '../core/dialog_support.dart';
import '../core/git_repos.dart';
import '../models/global_config.dart';
import '../models/skill_manifest.dart';
import 'options.dart';
import 'skills_command.dart';

/// Command to add a git repo as a skill source and install skills from it.
class AddCommand extends SkillsCommand {
  @override
  final String name = 'add';

  @override
  final String description =
      'Add a git repository as a skill source and install skills from it.';

  final DialogSupport? dialogSupport;

  AddCommand({this.dialogSupport}) {
    argParser
      ..addFlag(
        'global',
        help: 'Install the skill(s) globally.',
        defaultsTo: false,
      )
      ..addMultiOption(
        'skill',
        abbr: 's',
        help: 'Install the specific skills only.',
      )
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Install all skills from the given git repo.',
        negatable: false,
      );
  }

  @override
  Future<void> run() async {
    final argResults = this.argResults!;
    final rest = argResults.rest;
    if (rest.length != 1) {
      throw UsageException(
        'Must specify exactly one git repository URL to add, got '
        '${rest.length}',
        usage,
      );
    }

    final gitUrl = rest.single;
    final skillNames = argResults.multiOption('skill').toSet();
    final isGlobal = argResults.flag('global');
    final allFlag = argResults.flag('all');

    final repo = GitRepo(cloneUrl: gitUrl);

    final workspace = await resolveWorkspace();
    final rootPath = workspace.rootPath;

    if (isGlobal) {
      final globalConfigPath = GlobalConfig.globalPath;
      final globalConfigFile = File(globalConfigPath);
      var globalConfig = await GlobalConfig.loadOrEmpty(globalConfigFile);

      if (!globalConfig.gitRepos.any((r) => r.cloneUrl == repo.cloneUrl)) {
        globalConfig = globalConfig.withGitRepo(repo);
        await globalConfig.save(globalConfigFile);
        logger.info('Added ${repo.cloneUrl} to global config.');
      }
    } else {
      var manifest = await SkillManifest.loadOrEmptyFromRoot(rootPath);
      if (!manifest.gitRepos.any((r) => r.cloneUrl == repo.cloneUrl)) {
        manifest = manifest.withGitRepo(repo);
        await manifest.save(manifestFile(rootPath));
        logger.info('Added ${repo.cloneUrl} to local config.');
      }
    }

    final ides = await resolveIdes(
      argResults: argResults,
      projectPath: rootPath,
      dialogSupport: dialogSupport,
    );
    if (ides.isEmpty) return;

    await getSkills(
      ides: ides,
      logger: logger,
      workspace: workspace,
      dialogSupport: dialogSupport,
      usage: usage,
      sourceUris: {gitUrl},
      skillNames: skillNames,
      allFlag: allFlag,
    );
  }
}
