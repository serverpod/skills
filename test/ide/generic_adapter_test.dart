import 'dart:io';

import 'package:io/io.dart';
import 'package:skills/src/core/skill_scanner.dart';
import 'package:skills/src/core/stdin.dart';
import 'package:skills/src/ide/adapters/generic_adapter.dart';
import 'package:skills/src/models/skill_manifest.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

const _enter = [10];
const _downArrow = [27, 91, 66];

void main() {
  group('Given a GenericAdapter', () {
    late GenericAdapter adapter;

    setUp(() async {
      await d.dir('project', [
        d.dir('.agents', [d.dir('skills')]),
      ]).create();

      adapter = GenericAdapter(d.path('project'));
    });

    group('and a scanned skill', () {
      late ScannedSkill skill;

      setUp(() async {
        await d.dir('ag_pkg', [
          d.dir('skills', [
            d.dir('ag_pkg-data-analysis', [
              d.file('SKILL.md', '''
---
name: ag_pkg-data-analysis
description: Analyzes data.
---

# Data Analysis

Steps to analyze.
'''),
            ]),
          ]),
        ]).create();

        skill = ScannedSkill(
          packageName: 'ag_pkg',
          skillName: 'ag_pkg-data-analysis',
          skillPath: d.path('ag_pkg/skills/ag_pkg-data-analysis'),
        );
      });

      test('when installing then creates in .agents/skills/', () async {
        final name = await adapter.installSkill(skill);

        expect(name, equals('ag_pkg-data-analysis'));

        final installed = Directory(
          d.path('project/.agents/skills/ag_pkg-data-analysis'),
        );
        expect(await installed.exists(), isTrue);
      });

      test('when installing then SKILL.md is copied unchanged', () async {
        await adapter.installSkill(skill);

        final content = await File(
          d.path('project/.agents/skills/ag_pkg-data-analysis/SKILL.md'),
        ).readAsString();

        expect(content, contains('name: ag_pkg-data-analysis'));
        expect(content, contains('# Data Analysis'));
      });
    });

    test('when removing then deletes the skill directory', () async {
      await d.dir('project', [
        d.dir('.agents', [
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

      await adapter.removeSkill('pkg-skill');

      expect(
        await Directory(d.path('project/.agents/skills/pkg-skill')).exists(),
        isFalse,
      );
    });
  });

  group('migrateSkillsDir', () {
    late GenericAdapter adapter;
    late SkillManifest manifest;

    setUp(() async {
      await d.dir('project_migration', [
        d.dir('.agent', [
          d.dir('skills', [
            d.dir('old-skill', [
              d.file('SKILL.md', 'content'),
            ]),
          ]),
        ]),
      ]).create();

      adapter = GenericAdapter(d.path('project_migration'));

      manifest = const SkillManifest().withPackage(
        'generic',
        'pkg_a',
        PackageSkillsEntry(
          skills: [
            InstalledSkillEntry(
              name: 'old-skill',
              installedAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
    });

    test('migrates .agent to .agents', () async {
      await IOOverrides.runZoned(() async {
        await withSharedStdin(SharedStdIn(Stream.fromIterable([_enter])),
            () async {
          final migrated = await adapter.migrateSkillsDir(manifest);
          expect(migrated, isTrue);
          await adapter.ensureSkillsDirectory();
        });
      }, stdout: () => _DummyStdout());

      expect(
        await Directory(d.path('project_migration/.agents/skills/old-skill'))
            .exists(),
        isTrue,
      );
      expect(
        await Directory(d.path('project_migration/.agent')).exists(),
        isFalse,
      );
    });

    test('merges with existing .agents skills', () async {
      // Add something to .agents before migration
      final newSkillDir =
          Directory(d.path('project_migration/.agents/skills/new-skill'));
      await newSkillDir.create(recursive: true);
      await File(d.path('project_migration/.agents/skills/new-skill/SKILL.md'))
          .writeAsString('content');

      await IOOverrides.runZoned(() async {
        await withSharedStdin(SharedStdIn(Stream.fromIterable([_enter])),
            () async {
          final migrated = await adapter.migrateSkillsDir(manifest);
          expect(migrated, isTrue);
          await adapter.ensureSkillsDirectory();
        });
      }, stdout: () => _DummyStdout());

      expect(
        await Directory(d.path('project_migration/.agents/skills/old-skill'))
            .exists(),
        isTrue,
      );
      expect(
        await Directory(d.path('project_migration/.agents/skills/new-skill'))
            .exists(),
        isTrue,
      );
      expect(
        await Directory(d.path('project_migration/.agent')).exists(),
        isFalse,
      );
    });

    test('returns false if the user aborts', () async {
      await IOOverrides.runZoned(() async {
        await withSharedStdin(
            SharedStdIn(Stream.fromIterable(
                [_downArrow, _downArrow, _downArrow, _enter])), () async {
          final migrated = await adapter.migrateSkillsDir(manifest);
          expect(migrated, isFalse);
        });
      }, stdout: () => _DummyStdout());

      expect(
        await Directory(d.path('project_migration/.agent/skills/old-skill'))
            .exists(),
        isTrue,
      );
      expect(
        await Directory(d.path('project_migration/.agents/skills/old-skill'))
            .exists(),
        isFalse,
      );
    });
  });
}

/// Just swallows stdout so that it doesn't pollute the output.
class _DummyStdout implements Stdout {
  @override
  void writeln([Object? object = '']) {}

  @override
  void write(Object? object) {}

  @override
  bool get hasTerminal => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
