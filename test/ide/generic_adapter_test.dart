import 'dart:io';

import 'package:skills/src/core/skill_scanner.dart';
import 'package:skills/src/ide/adapters/generic_adapter.dart';
import 'package:skills/src/models/skill_manifest.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../fake_dialog_support.dart';

void main() {
  group('Given a GenericAdapter', () {
    late GenericAdapter adapter;
    late FakeDialogSupport fakeDialogSupport;

    setUp(() async {
      await d.dir('project', [
        d.dir('.agents', [d.dir('skills')]),
      ]).create();

      fakeDialogSupport = FakeDialogSupport();
      adapter = GenericAdapter(d.path('project'), fakeDialogSupport);
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

  group(
      'Given an existing ".agent" directory with skills and a generic adapter',
      () {
    late GenericAdapter adapter;
    late SkillManifest manifest;

    setUp(() async {
      await d.dir('project_migration', [
        d.dir('.agent', [
          d.dir('skills', [
            d.dir('old-skill', [
              d.file('SKILL.md', 'content'),
            ]),
            d.dir('unregistered-skill', [
              d.file('SKILL.md', 'content'),
            ]),
          ]),
        ]),
      ]).create();

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

    group('with dialog support', () {
      late FakeDialogSupport fakeDialogSupport;

      setUp(() async {
        fakeDialogSupport = FakeDialogSupport();
        adapter =
            GenericAdapter(d.path('project_migration'), fakeDialogSupport);
      });

      test('when the user chooses to migrate known skills', () async {
        fakeDialogSupport.singleSelectResult = 0;
        final migrated = await adapter.migrateSkillsDir(manifest);
        expect(migrated, isTrue);

        expect(
          await Directory(d.path('project_migration/.agents/skills/old-skill'))
              .exists(),
          isTrue,
          reason: 'then skills are migrated to the `.agents` directory',
        );
        expect(
          await Directory(d.path('project_migration/.agent/skills/old-skill'))
              .exists(),
          isFalse,
          reason: 'then the old skill directory is removed',
        );
        expect(
          await Directory(
                  d.path('project_migration/.agent/skills/unregistered-skill'))
              .exists(),
          isTrue,
          reason: 'then the unregistered skill directory is not removed',
        );
      });

      test('when the user chooses to migrate all skills', () async {
        fakeDialogSupport.singleSelectResult = 1;
        final migrated = await adapter.migrateSkillsDir(manifest);
        expect(migrated, isTrue);

        expect(
          await Directory(d.path('project_migration/.agents/skills/old-skill'))
              .exists(),
          isTrue,
          reason:
              'then the known skills are migrated to the `.agents` directory',
        );
        expect(
          await Directory(
                  d.path('project_migration/.agents/skills/unregistered-skill'))
              .exists(),
          isTrue,
          reason:
              'then the unknown skills are migrated to the `.agents` directory',
        );
        expect(
          await Directory(d.path('project_migration/.agent')).exists(),
          isFalse,
          reason: 'then the entire .agent skill directory is removed',
        );
      });

      test('when the user chooses to leave old skills in place', () async {
        fakeDialogSupport.singleSelectResult = 2;
        final migrated = await adapter.migrateSkillsDir(manifest);
        expect(migrated, isTrue);

        expect(
          await Directory(d.path('project_migration/.agents/skills/old-skill'))
              .exists(),
          isFalse,
          reason:
              'then the known skills are not migrated to the `.agents` directory',
        );
        expect(
          await Directory(
                  d.path('project_migration/.agents/skills/unregistered-skill'))
              .exists(),
          isFalse,
          reason:
              'then the unknown skills are not migrated to the `.agents` directory',
        );
        expect(
          await Directory(d.path('project_migration/.agent/skills/old-skill'))
              .exists(),
          isTrue,
          reason: 'then the old known skill is left in the .agent directory',
        );
        expect(
          await Directory(
                  d.path('project_migration/.agent/skills/unregistered-skill'))
              .exists(),
          isTrue,
          reason: 'then the old unknown skill is left in the .agent directory',
        );
      });

      test('when existing .agents skills exist', () async {
        // Add something to .agents before migration
        final newSkillDir =
            Directory(d.path('project_migration/.agents/skills/new-skill'));
        await newSkillDir.create(recursive: true);
        await File(
                d.path('project_migration/.agents/skills/new-skill/SKILL.md'))
            .writeAsString('content');

        fakeDialogSupport.singleSelectResult = 0;
        final migrated = await adapter.migrateSkillsDir(manifest);
        expect(migrated, isTrue);
        await adapter.ensureSkillsDirectory();

        expect(
            await Directory(
                    d.path('project_migration/.agents/skills/old-skill'))
                .exists(),
            isTrue,
            reason: 'then old .agents skills are still present');
        expect(
            await Directory(
                    d.path('project_migration/.agents/skills/new-skill'))
                .exists(),
            isTrue,
            reason: 'then existing .agent skills are moved into .agents');
        expect(
          await Directory(d.path('project_migration/.agent/skills/old-skill'))
              .exists(),
          isFalse,
          reason: 'then the old skill directory is removed',
        );
      });

      test('when migrating skills and user aborts the dialog', () async {
        fakeDialogSupport.singleSelectResult = 3;
        final migrated = await adapter.migrateSkillsDir(manifest);
        expect(migrated, isFalse);

        expect(
            await Directory(d.path('project_migration/.agent/skills/old-skill'))
                .exists(),
            isTrue,
            reason: 'then old .agent skills are preserved');
        expect(
            await Directory(
                    d.path('project_migration/.agents/skills/old-skill'))
                .exists(),
            isFalse,
            reason: 'then skills are not moved to .agents');
      });
    });

    group('without dialog support', () {
      setUp(() async {
        adapter = GenericAdapter(d.path('project_migration'), null);
      });

      test('when migrating skills', () async {
        final migrated = await adapter.migrateSkillsDir(manifest);
        expect(migrated, isTrue);
        await adapter.ensureSkillsDirectory();

        expect(
          await Directory(d.path('project_migration/.agents/skills/old-skill'))
              .exists(),
          isTrue,
          reason: 'then known skills are migrated to the `.agents` directory',
        );
        expect(
          await Directory(d.path('project_migration/.agent/skills/old-skill'))
              .exists(),
          isFalse,
          reason: 'then the old known skill directory is removed',
        );
        expect(
          await Directory(
                  d.path('project_migration/.agent/skills/unregistered-skill'))
              .exists(),
          isTrue,
          reason: 'then the old unknown skill directory is not removed',
        );
      });
    });
  });
}
