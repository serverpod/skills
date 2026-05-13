import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/commands/registry_command.dart';
import 'package:skills/src/commands/skills_command_runner.dart';
import 'package:skills/src/models/global_config.dart';
import 'package:skills/src/models/skill_manifest.dart';
import 'package:skills/src/core/registry_repos.dart';
import '../fake_dialog_support.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('RegistryCommand', () {
    late String projectPath;
    late String globalConfigPath;
    late FakeDialogSupport fakeDialogSupport;
    late CommandRunner<void> runner;

    setUp(() async {
      await d.dir('project', [
        d.file('pubspec.yaml', 'name: test_app'),
        d.dir('.dart_skills', []),
      ]).create();
      projectPath = d.path('project');

      await d.dir('global_config_dir', []).create();
      globalConfigPath =
          p.join(d.path('global_config_dir'), 'global_config.json');
      GlobalConfig.globalPathOverride = globalConfigPath;

      fakeDialogSupport = FakeDialogSupport();

      runner = SkillsCommandRunner('skills', 'Test',
          dialogSupport: fakeDialogSupport)
        ..addCommand(RegistryCommand(dialogSupport: fakeDialogSupport));
    });

    tearDown(() {
      GlobalConfig.globalPathOverride = null;
    });

    test('add command adds to global config by default when prompted',
        () async {
      fakeDialogSupport.singleSelectResult = 0; // Select 'Global'

      await runner
          .run(['-C', projectPath, 'registry', 'add', 'flutter/skills']);

      final globalConfig =
          await GlobalConfig.loadOrEmpty(File(globalConfigPath));
      expect(globalConfig.registries, hasLength(1));
      expect(globalConfig.registries.first.owner, equals('flutter'));
      expect(globalConfig.registries.first.name, equals('skills'));
    });

    test('add command adds to local config when prompted', () async {
      fakeDialogSupport.singleSelectResult = 1; // Select 'Local'

      await runner.run(
          ['-C', projectPath, 'registry', 'add', 'serverpod/skills-registry']);

      final manifest = await SkillManifest.loadOrEmpty(
          File(SkillManifest.pathIn(projectPath)));
      expect(manifest.registries, hasLength(1));
      expect(manifest.registries.first.owner, equals('serverpod'));
      expect(manifest.registries.first.name, equals('skills-registry'));
    });

    test('add command respects --global flag', () async {
      await runner.run(
          ['-C', projectPath, 'registry', 'add', '--global', 'flutter/skills']);

      final globalConfig =
          await GlobalConfig.loadOrEmpty(File(globalConfigPath));
      expect(globalConfig.registries, hasLength(1));
    });

    test('add command respects --no-global flag', () async {
      await runner.run([
        '-C',
        projectPath,
        'registry',
        'add',
        '--no-global',
        'serverpod/skills-registry'
      ]);

      final manifest = await SkillManifest.loadOrEmpty(
          File(SkillManifest.pathIn(projectPath)));
      expect(manifest.registries, hasLength(1));
    });

    test('add command parses Git URI correctly', () async {
      await runner.run([
        '-C',
        projectPath,
        'registry',
        'add',
        '--global',
        'https://github.com/dart-lang/skills.git'
      ]);

      final globalConfig =
          await GlobalConfig.loadOrEmpty(File(globalConfigPath));
      expect(globalConfig.registries, hasLength(1));
      expect(globalConfig.registries.first.owner, equals('dart-lang'));
      expect(globalConfig.registries.first.name, equals('skills'));
    });

    test('list command lists both global and local registries', () async {
      var globalConfig = const GlobalConfig();
      globalConfig = globalConfig
          .withRegistry(const RegistryRepo(owner: 'g_owner', name: 'g_repo'));
      await globalConfig.save(File(globalConfigPath));

      var manifest = const SkillManifest();
      manifest = manifest
          .withRegistry(const RegistryRepo(owner: 'l_owner', name: 'l_repo'));
      await manifest.save(File(SkillManifest.pathIn(projectPath)));

      final logs = <String>[];
      final subscription = Logger.root.onRecord.listen((log) {
        logs.add(log.message);
      });

      await runner.run(['-C', projectPath, 'registry', 'list']);

      await subscription.cancel();

      expect(logs, contains(contains('g_owner/g_repo')));
      expect(logs, contains(contains('l_owner/l_repo')));
    });

    test('remove command removes from local when only there', () async {
      var manifest = const SkillManifest();
      const repo = RegistryRepo(owner: 'l_owner', name: 'l_repo');
      manifest = manifest.withRegistry(repo);
      await manifest.save(File(SkillManifest.pathIn(projectPath)));

      await runner
          .run(['-C', projectPath, 'registry', 'remove', 'l_owner/l_repo']);

      final updatedManifest = await SkillManifest.loadOrEmpty(
          File(SkillManifest.pathIn(projectPath)));
      expect(updatedManifest.registries, isEmpty);
    });

    test('remove command removes from global when only there', () async {
      var globalConfig = const GlobalConfig();
      const repo = RegistryRepo(owner: 'g_owner', name: 'g_repo');
      globalConfig = globalConfig.withRegistry(repo);
      await globalConfig.save(File(globalConfigPath));

      await runner
          .run(['-C', projectPath, 'registry', 'remove', 'g_owner/g_repo']);

      final updatedGlobalConfig =
          await GlobalConfig.loadOrEmpty(File(globalConfigPath));
      expect(updatedGlobalConfig.registries, isEmpty);
    });

    test('remove command prompts when in both and removes selected', () async {
      const repo = RegistryRepo(owner: 'both_owner', name: 'both_repo');

      var globalConfig = const GlobalConfig();
      globalConfig = globalConfig.withRegistry(repo);
      await globalConfig.save(File(globalConfigPath));

      var manifest = const SkillManifest();
      manifest = manifest.withRegistry(repo);
      await manifest.save(File(SkillManifest.pathIn(projectPath)));

      fakeDialogSupport.singleSelectResult = 0; // Select 'Global'

      await runner.run(
          ['-C', projectPath, 'registry', 'remove', 'both_owner/both_repo']);

      final updatedGlobalConfig =
          await GlobalConfig.loadOrEmpty(File(globalConfigPath));
      expect(updatedGlobalConfig.registries, isEmpty);

      final updatedManifest = await SkillManifest.loadOrEmpty(
          File(SkillManifest.pathIn(projectPath)));
      expect(updatedManifest.registries, hasLength(1)); // Still in local
    });

    test('remove command with no args shows multi-select and removes selected',
        () async {
      const repo1 = RegistryRepo(owner: 'owner1', name: 'repo1');
      const repo2 = RegistryRepo(owner: 'owner2', name: 'repo2');

      var globalConfig = const GlobalConfig();
      globalConfig = globalConfig.withRegistry(repo1);
      await globalConfig.save(File(globalConfigPath));

      var manifest = const SkillManifest();
      manifest = manifest.withRegistry(repo2);
      await manifest.save(File(SkillManifest.pathIn(projectPath)));

      fakeDialogSupport.multiSelectResult = {
        0
      }; // Select first option (global one)

      await runner.run(['-C', projectPath, 'registry', 'remove']);

      final updatedGlobalConfig =
          await GlobalConfig.loadOrEmpty(File(globalConfigPath));
      expect(updatedGlobalConfig.registries, isEmpty);

      final updatedManifest = await SkillManifest.loadOrEmpty(
          File(SkillManifest.pathIn(projectPath)));
      expect(updatedManifest.registries, hasLength(1)); // Still in local
    });
  });
}
