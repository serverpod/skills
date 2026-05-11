import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:skills/src/commands/remove_command.dart';
import '../fake_dialog_support.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

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

      await d.dir('project', [
        d.dir('.cursor', [
          d.dir('skills', [
            d.nothing('dep1-skill'),
            d.dir('dep2-skill'),
          ]),
        ]),
        d.dir('.dart_skills', [
          d.file(
            'skills_config.json',
            allOf(
              isNot(contains('dep1-skill')),
              contains('dep2-skill'),
            ),
          ),
        ]),
      ]).validate();
    });

    test('when running `skills remove all` then removes all skills', () async {
      final removeCommand = RemoveCommand(dialogSupport: fakeDialogSupport);
      final runner = CommandRunner<void>('skills', 'Test')
        ..addCommand(removeCommand);

      await runner.run(
          ['remove', '--directory', projectPath, '--ide', 'cursor', 'all']);

      await d.dir('project', [
        d.dir('.cursor', [
          d.dir('skills', [
            d.nothing('dep1-skill'),
            d.nothing('dep2-skill'),
          ]),
        ]),
        d.nothing('.dart_skills'),
      ]).validate();
    });

    test(
        'when running `skills remove` without arguments and selecting all then removes all skills for that IDE',
        () async {
      fakeDialogSupport.multiSelectResult = {0, 1};
      final removeCommand = RemoveCommand(dialogSupport: fakeDialogSupport);
      final runner = CommandRunner<void>('skills', 'Test')
        ..addCommand(removeCommand);

      await runner
          .run(['remove', '--directory', projectPath, '--ide', 'cursor']);

      await d.dir('project', [
        d.dir('.cursor', [
          d.dir('skills', [
            d.nothing('dep1-skill'),
            d.nothing('dep2-skill'),
          ]),
        ]),
        d.nothing('.dart_skills'),
      ]).validate();
    });

    test(
        'when running `skills remove` without arguments and NO dialog support '
        'then does nothing and prints packages', () async {
      final removeCommand = RemoveCommand(dialogSupport: null);
      final runner = CommandRunner<void>('skills', 'Test')
        ..addCommand(removeCommand);

      await runner
          .run(['remove', '--directory', projectPath, '--ide', 'cursor']);

      await d.dir('project', [
        d.dir('.cursor', [
          d.dir('skills', [
            d.dir('dep1-skill'),
            d.dir('dep2-skill'),
          ]),
        ]),
        d.dir('.dart_skills', [
          d.file('skills_config.json', contains('dep1-skill')),
        ]),
      ]).validate();
    });
  });
}
