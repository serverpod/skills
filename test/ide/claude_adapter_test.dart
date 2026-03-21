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

    group('user-invocable guard edge cases', () {
      test(
        'preserves explicit user-invocable: true',
        () async {
          await d.dir('claude_pkg_true', [
            d.dir('skills', [
              d.dir('claude_pkg_true-review', [
                d.file('SKILL.md', '''
---
name: claude_pkg_true-review
description: Reviews code.
user-invocable: true
---

# Code Review
'''),
              ]),
            ]),
          ]).create();

          final skill = ScannedSkill(
            packageName: 'claude_pkg_true',
            skillName: 'claude_pkg_true-review',
            skillPath: d.path('claude_pkg_true/skills/claude_pkg_true-review'),
          );

          await adapter.installSkill(skill);

          final content = await File(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg_true-review',
              'SKILL.md',
            ),
          ).readAsString();

          expect(content, contains('user-invocable: true'));
          expect(content, isNot(contains('user-invocable: false')));
        },
      );

      test(
        'no duplication when user-invocable: false already present',
        () async {
          await d.dir('claude_pkg_dup', [
            d.dir('skills', [
              d.dir('claude_pkg_dup-lint', [
                d.file('SKILL.md', '''
---
name: claude_pkg_dup-lint
description: Lints code.
user-invocable: false
---

# Lint
'''),
              ]),
            ]),
          ]).create();

          final skill = ScannedSkill(
            packageName: 'claude_pkg_dup',
            skillName: 'claude_pkg_dup-lint',
            skillPath: d.path('claude_pkg_dup/skills/claude_pkg_dup-lint'),
          );

          await adapter.installSkill(skill);

          final content = await File(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg_dup-lint',
              'SKILL.md',
            ),
          ).readAsString();

          final matches = 'user-invocable: false'.allMatches(content).length;
          expect(matches, equals(1));
        },
      );

      test(
        'preserves nested frontmatter fields byte-for-byte',
        () async {
          await d.dir('claude_pkg_nested', [
            d.dir('skills', [
              d.dir('claude_pkg_nested-deploy', [
                d.file('SKILL.md', '''
---
name: claude_pkg_nested-deploy
description: Deploys stuff.
metadata:
  version: 2
  tags:
    - deploy
    - ci
---

# Deploy
'''),
              ]),
            ]),
          ]).create();

          final skill = ScannedSkill(
            packageName: 'claude_pkg_nested',
            skillName: 'claude_pkg_nested-deploy',
            skillPath: d.path(
              'claude_pkg_nested/skills/claude_pkg_nested-deploy',
            ),
          );

          await adapter.installSkill(skill);

          final content = await File(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg_nested-deploy',
              'SKILL.md',
            ),
          ).readAsString();

          expect(content, contains('user-invocable: false'));
          expect(content, contains('metadata:'));
          expect(content, contains('  version: 2'));
          expect(content, contains('  tags:'));
          expect(content, contains('    - deploy'));
          expect(content, contains('    - ci'));
        },
      );

      test(
        'handles SKILL.md with no body',
        () async {
          await d.dir('claude_pkg_nobody', [
            d.dir('skills', [
              d.dir('claude_pkg_nobody-empty', [
                d.file('SKILL.md', '''
---
name: claude_pkg_nobody-empty
description: Empty body skill.
---'''),
              ]),
            ]),
          ]).create();

          final skill = ScannedSkill(
            packageName: 'claude_pkg_nobody',
            skillName: 'claude_pkg_nobody-empty',
            skillPath: d.path(
              'claude_pkg_nobody/skills/claude_pkg_nobody-empty',
            ),
          );

          await adapter.installSkill(skill);

          final content = await File(
            p.join(
              d.path('project'),
              '.claude',
              'skills',
              'claude_pkg_nobody-empty',
              'SKILL.md',
            ),
          ).readAsString();

          expect(content, contains('user-invocable: false'));
          expect(content, contains('---'));
          // Verify valid format: opening and closing ---
          final dashes = '---'.allMatches(content).length;
          expect(dashes, greaterThanOrEqualTo(2));
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
