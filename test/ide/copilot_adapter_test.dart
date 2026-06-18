import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/core/skill_scanner.dart';
import 'package:skills/src/ide/adapters/copilot_adapter.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import '../utils.dart';

void main() {
  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

  group('Given a CopilotAdapter', () {
    late CopilotAdapter adapter;

    setUp(() async {
      await d.dir('project', [
        d.dir('.github', [d.dir('skills')]),
      ]).create();

      adapter = CopilotAdapter(d.path('project'));
    });

    group('and a scanned skill', () {
      late ScannedSkill skill;

      setUp(() async {
        await d.dir('copilot_pkg', [
          d.dir('skills', [
            skillDir(
              'copilot_pkg-testing',
              extraFrontMatter: 'description: Testing best practices.',
              skillContent: '''# Testing

Write tests like this.''',
            ),
          ]),
        ]).create();

        skill = ScannedSkill(
          packageName: 'copilot_pkg',
          skillPath: d.path('copilot_pkg/skills/copilot_pkg-testing'),
          frontmatter: .new('copilot_pkg-testing', isInternal: false),
        );
      });

      test(
        'when installing then creates skill directory in .github/skills/',
        () async {
          final name = (await adapter.installSkill(skill)).name;

          expect(name, equals('copilot_pkg-testing'));

          final installed = Directory(
            p.join(
              d.path('project'),
              '.github',
              'skills',
              'copilot_pkg-testing',
            ),
          );
          expect(await installed.exists(), isTrue);
        },
      );

      test('when installing then SKILL.md is copied unchanged', () async {
        await adapter.installSkill(skill);

        final content = await File(
          p.join(
            d.path('project'),
            '.github',
            'skills',
            'copilot_pkg-testing',
            'SKILL.md',
          ),
        ).readAsString();

        expect(content, contains('name: copilot_pkg-testing'));
        expect(content, contains('# Testing'));
      });
    });

    test('when removing then deletes the skill directory', () async {
      await d.dir('project', [
        d.dir('.github', [
          d.dir('skills', [
            skillDir(
              'pkg-skill',
              extraFrontMatter: 'description: x',
              skillContent: 'body',
            ),
          ]),
        ]),
      ]).create();

      adapter = CopilotAdapter(d.path('project'));
      await adapter.removeSkill('pkg-skill');

      expect(
        await Directory(
          p.join(d.path('project'), '.github', 'skills', 'pkg-skill'),
        ).exists(),
        isFalse,
      );
    });
  });
}
