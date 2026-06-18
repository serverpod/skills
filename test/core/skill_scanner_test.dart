import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/core/package_resolver.dart';
import 'package:skills/src/core/skill_scanner.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import '../utils.dart';

void main() {
  late Logger logger;

  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

  group('Given a package with correctly prefixed skills', () {
    late ResolvedPackage package;

    setUp(() async {
      logger = Logger('SkillScanner test');
      await d.dir('my_package', [
        d.dir('skills', [
          skillDir(
            'my_package-code-gen',
            extraFrontMatter: 'description: Generates code.',
            skillContent: '''# Code Gen

Instructions.''',
          ),
          skillDir(
            'my_package-api-design',
            extraFrontMatter: 'description: Designs APIs.',
            skillContent: '''# API Design

Instructions.''',
          ),
        ]),
      ]).create();

      package = ResolvedPackage(
        name: 'my_package',
        rootPath: d.path('my_package'),
        originalPackageConfigPath: d.path(
          p.join('.dart_tool', 'package_config.json'),
        ),
      );
    });

    test('when scanning then finds all valid skills', () async {
      final scanner = SkillScanner(logger);
      final skills = await scanner.scanPackage(package);

      expect(skills, hasLength(2));
      expect(
        skills.map((s) => s.basename).toSet(),
        equals({'my_package-code-gen', 'my_package-api-design'}),
      );
    });

    test('when scanning then skill paths point to skill directories', () async {
      final scanner = SkillScanner(logger);
      final skills = await scanner.scanPackage(package);

      for (final skill in skills) {
        expect(skill.skillPath, contains(p.join('my_package', 'skills')));
        expect(skill.packageName, equals('my_package'));
      }
    });
  });

  group(
    'Given a package with a skill that does not match the package prefix',
    () {
      test('when scanning then the misnamed skill is skipped', () async {
        await d.dir('my_package', [
          d.dir('skills', [
            skillDir(
              'my_package-valid',
              extraFrontMatter: 'description: Valid.',
              skillContent: 'Body.',
            ),
            skillDir(
              'wrong-prefix-skill',
              extraFrontMatter: 'description: Invalid.',
              skillContent: 'Body.',
            ),
          ]),
        ]).create();

        final package = ResolvedPackage(
          name: 'my_package',
          rootPath: d.path('my_package'),
          originalPackageConfigPath: d.path(
            p.join('.dart_tool', 'package_config.json'),
          ),
        );

        final scanner = SkillScanner(logger);
        final skills = await scanner.scanPackage(package);

        expect(skills, hasLength(1));
        expect(skills.first.basename, equals('my_package-valid'));
      });
    },
  );

  group('Given a package with a malformed skill', () {
    test(
      'when scanning then the malformed skill is skipped and a warning is logged',
      () async {
        final logs = <LogRecord>[];
        final subscription = logger.onRecord.listen(logs.add);

        await d.dir('malformed_pkg', [
          d.dir('skills', [
            skillDir(
              'malformed_pkg-valid',
              extraFrontMatter: 'description: Valid skill.',
              skillContent: 'Body.',
            ),
            d.dir('malformed_pkg-invalid', [
              // Malformed frontmatter (e.g., missing name)
              d.file('SKILL.md', '''
---
description: Invalid skill.
---
Body.
'''),
            ]),
          ]),
        ]).create();

        final package = ResolvedPackage(
          name: 'malformed_pkg',
          rootPath: d.path('malformed_pkg'),
          originalPackageConfigPath: d.path(
            p.join('.dart_tool', 'package_config.json'),
          ),
        );

        final scanner = SkillScanner(logger);
        final skills = await scanner.scanPackage(package);

        await subscription.cancel();

        expect(skills, hasLength(1));
        expect(skills.first.basename, equals('malformed_pkg-valid'));

        expect(
          logs,
          contains(
            isA<LogRecord>()
                .having((r) => r.level, 'level', equals(Level.WARNING))
                .having(
                  (r) => r.message,
                  'message',
                  contains('due to formatting error'),
                ),
          ),
        );
      },
    );
  });

  group('Given a package without a skills directory', () {
    test('when scanning then returns empty list', () async {
      await d.dir('no_skills_package', [
        d.dir('lib', [d.file('main.dart', 'void main() {}')]),
      ]).create();

      final package = ResolvedPackage(
        name: 'no_skills_package',
        rootPath: d.path('no_skills_package'),
        originalPackageConfigPath: d.path(
          p.join('.dart_tool', 'package_config.json'),
        ),
      );

      final scanner = SkillScanner(logger);
      final skills = await scanner.scanPackage(package);

      expect(skills, isEmpty);
    });
  });

  group('Given a package with a skills directory but no SKILL.md files', () {
    test('when scanning then returns empty list', () async {
      await d.dir('empty_skills', [
        d.dir('skills', [
          d.dir('empty_skills-not-a-skill', [
            d.file('README.md', 'not a skill'),
          ]),
        ]),
      ]).create();

      final package = ResolvedPackage(
        name: 'empty_skills',
        rootPath: d.path('empty_skills'),
        originalPackageConfigPath: d.path(
          p.join('.dart_tool', 'package_config.json'),
        ),
      );

      final scanner = SkillScanner(logger);
      final skills = await scanner.scanPackage(package);

      expect(skills, isEmpty);
    });
  });

  group('Given multiple packages', () {
    test('when scanning all then aggregates skills from each', () async {
      await d.dir('pkg_a', [
        d.dir('skills', [
          skillDir(
            'pkg_a-skill-a',
            extraFrontMatter: 'description: Skill A.',
            skillContent: 'Body A.',
          ),
        ]),
      ]).create();

      await d.dir('pkg_b', [
        d.dir('skills', [
          skillDir(
            'pkg_b-skill-b',
            extraFrontMatter: 'description: Skill B.',
            skillContent: 'Body B.',
          ),
        ]),
      ]).create();

      final packages = [
        ResolvedPackage(
          name: 'pkg_a',
          rootPath: d.path('pkg_a'),
          originalPackageConfigPath: d.path(
            p.join('.dart_tool', 'package_config.json'),
          ),
        ),
        ResolvedPackage(
          name: 'pkg_b',
          rootPath: d.path('pkg_b'),
          originalPackageConfigPath: d.path(
            p.join('.dart_tool', 'package_config.json'),
          ),
        ),
      ];

      final scanner = SkillScanner(logger);
      final skills = await scanner.scan(packages);

      expect(skills, hasLength(2));
      expect(
        skills.map((s) => s.packageName).toSet(),
        equals({'pkg_a', 'pkg_b'}),
      );
    });
  });

  group('Given a package with an internal skill', () {
    test('when scanning then skips the internal skill by default', () async {
      await d.dir('internal_pkg', [
        d.dir('skills', [
          skillDir(
            'internal_pkg-public',
            extraFrontMatter: '''metadata:
  internal: false''',
            skillContent: 'Public skill.',
          ),
          skillDir(
            'internal_pkg-private',
            extraFrontMatter: '''metadata:
  internal: true''',
            skillContent: 'Private skill.',
          ),
        ]),
      ]).create();

      final package = ResolvedPackage(
        name: 'internal_pkg',
        rootPath: d.path('internal_pkg'),
        originalPackageConfigPath: d.path(
          p.join('.dart_tool', 'package_config.json'),
        ),
      );

      final scanner = SkillScanner(logger);
      final skills = await scanner.scanPackage(package);

      expect(skills, hasLength(1));
      expect(skills.first.basename, equals('internal_pkg-public'));
      expect(skills.first.frontmatter.isInternal, isFalse);
    });
  });

  group('SkillFrontmatter', () {
    test('parses name and internal: true correctly', () {
      final frontmatter = SkillFrontmatter.fromSkillContent('''
---
name: my-skill
metadata:
  internal: true
---
Body
''');
      expect(frontmatter.name, equals('my-skill'));
      expect(frontmatter.isInternal, isTrue);
    });

    test('parses name and defaults to internal: false', () {
      final frontmatter = SkillFrontmatter.fromSkillContent('''
---
name: my-skill
---
Body
''');
      expect(frontmatter.name, equals('my-skill'));
      expect(frontmatter.isInternal, isFalse);
    });

    test('throws FormatException if name is missing', () {
      expect(
        () => SkillFrontmatter.fromSkillContent('''
---
metadata:
  internal: true
---
Body
'''),
        throwsFormatException,
      );
    });

    test('throws FormatException if frontmatter is missing', () {
      expect(
        () => SkillFrontmatter.fromSkillContent('Body only no frontmatter'),
        throwsFormatException,
      );
    });
  });
}
