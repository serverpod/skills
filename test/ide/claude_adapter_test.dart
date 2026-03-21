import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skills/src/core/skill_scanner.dart';
import 'package:skills/src/ide/adapters/claude_adapter.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Given a ClaudeAdapter', () {
    late ClaudeAdapter adapter;

    setUp(() async {
      await d.dir('project', [
        d.dir('.claude', [d.dir('skills')]),
      ]).create();

      adapter = ClaudeAdapter(d.path('project'));
    });

    group('and a scanned skill', () {
      late ScannedSkill skill;

      setUp(() async {
        await d.dir('claude_pkg', [
          d.dir('skills', [
            d.dir('claude_pkg-code-review', [
              d.file('SKILL.md', '''
---
name: claude_pkg-code-review
description: Reviews code.
---

# Code Review

Review guidelines here.
'''),
            ]),
          ]),
        ]).create();

        skill = ScannedSkill(
          packageName: 'claude_pkg',
          skillName: 'claude_pkg-code-review',
          skillPath: d.path('claude_pkg/skills/claude_pkg-code-review'),
        );
      });

      test(
        'when installing then creates skill directory in .claude/skills/',
        () async {
          final name = await adapter.installSkill(skill);

          expect(name, equals('claude_pkg-code-review'));

          final installed = Directory(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg-code-review',
            ),
          );
          expect(await installed.exists(), isTrue);
        },
      );

      test(
        'when installing then SKILL.md includes user-invocable: false',
        () async {
          await adapter.installSkill(skill);

          final content = await File(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg-code-review',
              'SKILL.md',
            ),
          ).readAsString();

          expect(content, contains('name: claude_pkg-code-review'));
          expect(content, contains('user-invocable: false'));
          expect(content, contains('# Code Review'));
        },
      );

      test(
        'when installing a SKILL.md without user-invocable '
        'then injects user-invocable: false and preserves content',
        () async {
          final name = await adapter.installSkill(skill);

          expect(name, equals('claude_pkg-code-review'));

          final content = await File(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg-code-review',
              'SKILL.md',
            ),
          ).readAsString();

          expect(content, contains('user-invocable: false'));
          expect(content, contains('name: claude_pkg-code-review'));
          expect(content, contains('description: Reviews code.'));
          expect(content, contains('# Code Review'));
          expect(
            content,
            contains('Review guidelines here.'),
          );
        },
      );
    });

    test('when removing then deletes the skill directory', () async {
      await d.dir('project', [
        d.dir('.claude', [
          d.dir('skills', [
            d.dir('pkg-skill', [
              d.file(
                'SKILL.md',
                '---\nname: pkg-skill\n'
                    'description: x\n---\nbody',
              ),
            ]),
          ]),
        ]),
      ]).create();

      adapter = ClaudeAdapter(d.path('project'));
      await adapter.removeSkill('pkg-skill');

      expect(
        await Directory(
          p.join(d.path('project'), '.claude', 'skills', 'pkg-skill'),
        ).exists(),
        isFalse,
      );
    });
  });
}
