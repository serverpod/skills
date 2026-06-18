import 'package:logging/logging.dart';
import 'package:skills/src/core/skill_merger.dart';
import 'package:skills/src/core/skill_scanner.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

  group('mergeSkills', () {
    test(
      'when package has both dart and registry skills then only dart included',
      () {
        final dartSkills = [
          ScannedSkill(
            packageName: 'pkg_a',
            frontmatter: .new('pkg_a-dart-skill', isInternal: false),
            skillPath: '/dart/pkg_a/skills/pkg_a-dart-skill',
          ),
        ];
        final registrySkills = [
          ScannedSkill(
            packageName: 'pkg_a',
            skillPath: '/repos/owner/repo/skills/pkg_a-registry-skill',
            frontmatter: .new('pkg_a-registry-skill', isInternal: false),
          ),
        ];
        final resolved = {'pkg_a'};

        final result = mergeSkills(
          dartSkills: dartSkills,
          registrySkills: registrySkills,
          resolvedPackageNames: resolved,
        );

        expect(result, hasLength(1));
        expect(result.single.basename, equals('pkg_a-dart-skill'));
      },
    );

    test(
      'when package only in registry and in deps then registry included',
      () {
        final dartSkills = <ScannedSkill>[];
        final registrySkills = [
          ScannedSkill(
            packageName: 'pkg_b',
            skillPath: '/repos/flutter/skills/skills/pkg_b-buttons',
            frontmatter: .new('pkg_b-buttons', isInternal: false),
          ),
        ];
        final resolved = {'pkg_b'};

        final result = mergeSkills(
          dartSkills: dartSkills,
          registrySkills: registrySkills,
          resolvedPackageNames: resolved,
        );

        expect(result, hasLength(1));
        expect(result.single.basename, equals('pkg_b-buttons'));
      },
    );

    test('when package only in registry but not in deps then excluded', () {
      final dartSkills = <ScannedSkill>[];
      final registrySkills = [
        ScannedSkill(
          packageName: 'other_pkg',
          skillPath: '/repos/skills/other_pkg-foo',
          frontmatter: .new('other_pkg-foo', isInternal: false),
        ),
      ];
      final resolved = {'pkg_a'}; // only pkg_a is a dependency

      final result = mergeSkills(
        dartSkills: dartSkills,
        registrySkills: registrySkills,
        resolvedPackageNames: resolved,
      );

      expect(result, isEmpty);
    });

    test('when mixed then dart plus filtered registry', () {
      final dartSkills = [
        ScannedSkill(
          packageName: 'pkg_a',
          skillPath: '/dart/pkg_a/skills/pkg_a-dart',
          frontmatter: .new('pkg_a-dart', isInternal: false),
        ),
      ];
      final registrySkills = [
        ScannedSkill(
          packageName: 'pkg_a',
          skillPath: '/repos/skills/pkg_a-registry',
          frontmatter: .new('pkg_a-registry', isInternal: false),
        ),
        ScannedSkill(
          packageName: 'pkg_b',
          skillPath: '/repos/skills/pkg_b-registry',
          frontmatter: .new('pkg_b-registry', isInternal: false),
        ),
      ];
      final resolved = {'pkg_a', 'pkg_b'};

      final result = mergeSkills(
        dartSkills: dartSkills,
        registrySkills: registrySkills,
        resolvedPackageNames: resolved,
      );

      expect(result, hasLength(2));
      expect(
        result.map((s) => s.basename).toSet(),
        equals({'pkg_a-dart', 'pkg_b-registry'}),
      );
    });
  });
}
