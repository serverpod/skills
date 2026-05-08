import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/commands/remove_command.dart';
import 'package:skills/src/models/skill_manifest.dart';
import '../fake_dialog_support.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Given a project with installed skills for dep1 and dep2', () {
    late String projectPath;
    late FakeDialogSupport fakeDialogSupport;

    setUp(() async {
      final projectRootDir = d.dir('project', [
        d.file('pubspec.yaml', '''
name: test_app
environment:
  sdk: ^3.0.0
'''),
        d.dir('.dart_tool', [
          d.file(
            'package_config.json',
            jsonEncode({
              'configVersion': 2,
              'packages': [
                {'name': 'test_app', 'rootUri': '../', 'packageUri': 'lib/'},
                {'name': 'dep1', 'rootUri': '../../dep1', 'packageUri': 'lib/'},
                {'name': 'dep2', 'rootUri': '../../dep2', 'packageUri': 'lib/'},
              ],
            }),
          ),
        ]),
        d.dir('.cursor', [
          d.dir('skills', [
            d.dir('dep1-skill', [d.file('SKILL.md', 'content')]),
            d.dir('dep2-skill', [d.file('SKILL.md', 'content')]),
          ]),
        ]),
        d.dir('.dart_skills', [
          d.file(
              'skills_config.json',
              jsonEncode({
                'version': 1,
                'installations': {
                  'cursor': {
                    'dep1': {
                      'skills': [
                        {
                          'name': 'dep1-skill',
                          'installedAt': '2026-05-08T18:00:00Z'
                        }
                      ]
                    },
                    'dep2': {
                      'skills': [
                        {
                          'name': 'dep2-skill',
                          'installedAt': '2026-05-08T18:00:00Z'
                        }
                      ]
                    }
                  }
                }
              })),
        ]),
      ]);
      await projectRootDir.create();

      projectPath = projectRootDir.io.path;
      fakeDialogSupport = FakeDialogSupport();
    });

    test('when running `skills remove dep1` then removes only dep1 skills',
        () async {
      final removeCommand = RemoveCommand(dialogSupport: fakeDialogSupport);
      final runner = CommandRunner<void>('skills', 'Test')
        ..addCommand(removeCommand);

      await runner.run(
          ['remove', '--directory', projectPath, '--ide', 'cursor', 'dep1']);

      final dep1SkillDir =
          Directory(p.join(projectPath, '.cursor', 'skills', 'dep1-skill'));
      final dep2SkillDir =
          Directory(p.join(projectPath, '.cursor', 'skills', 'dep2-skill'));

      expect(await dep1SkillDir.exists(), isFalse,
          reason: 'dep1 skill should be removed');
      expect(await dep2SkillDir.exists(), isTrue,
          reason: 'dep2 skill should still exist');

      final manifestFile = File(SkillManifest.pathIn(projectPath));
      final manifest = await SkillManifest.loadOrEmpty(manifestFile);
      final skillNames =
          manifest.allSkillsForIde('cursor').map((e) => e.name).toSet();
      expect(skillNames, isNot(contains('dep1-skill')));
      expect(skillNames, contains('dep2-skill'));
    });

    test('when running `skills remove all` then removes all skills', () async {
      final removeCommand = RemoveCommand(dialogSupport: fakeDialogSupport);
      final runner = CommandRunner<void>('skills', 'Test')
        ..addCommand(removeCommand);

      await runner.run(
          ['remove', '--directory', projectPath, '--ide', 'cursor', 'all']);

      final dep1SkillDir =
          Directory(p.join(projectPath, '.cursor', 'skills', 'dep1-skill'));
      final dep2SkillDir =
          Directory(p.join(projectPath, '.cursor', 'skills', 'dep2-skill'));

      expect(await dep1SkillDir.exists(), isFalse);
      expect(await dep2SkillDir.exists(), isFalse);

      final manifestDir = Directory(p.join(projectPath, '.dart_skills'));
      expect(await manifestDir.exists(), isFalse,
          reason: 'Manifest dir should be deleted when empty');
    });

    test(
        'when running `skills remove` without arguments then removes all skills for that IDE',
        () async {
      final removeCommand = RemoveCommand(dialogSupport: fakeDialogSupport);
      final runner = CommandRunner<void>('skills', 'Test')
        ..addCommand(removeCommand);

      await runner
          .run(['remove', '--directory', projectPath, '--ide', 'cursor']);

      final dep1SkillDir =
          Directory(p.join(projectPath, '.cursor', 'skills', 'dep1-skill'));
      final dep2SkillDir =
          Directory(p.join(projectPath, '.cursor', 'skills', 'dep2-skill'));

      expect(await dep1SkillDir.exists(), isFalse);
      expect(await dep2SkillDir.exists(), isFalse);

      final manifestDir = Directory(p.join(projectPath, '.dart_skills'));
      expect(await manifestDir.exists(), isFalse);
    });
  });
}
