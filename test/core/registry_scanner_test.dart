import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/core/registry_repos.dart';
import 'package:skills/src/core/registry_scanner.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import '../utils.dart';

void main() {
  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

  group('RegistryScanner', () {
    test('when repos directory does not exist then returns empty', () async {
      await d.dir('project', []).create();
      const scanner = RegistryScanner();
      final skills = await scanner.scan(d.path('project'), isGlobal: false);
      expect(skills, isEmpty);
    });

    test(
      'when scanning flat layout then returns ScannedSkills with correct fields',
      () async {
        const registryRepo = RegistryRepo(
          cloneUrl: 'https://github.com/owner/repo.git',
        );
        await d.dir('project', [
          d.dir('.dart_tool', [
            d.dir('skills', [
              d.dir('repos', [
                d.dir(registryRepo.pathSegment, [
                  d.dir('skills', [
                    skillDir('my_pkg-buttons'),
                    skillDir('my_pkg-forms'),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ]).create();

        const scanner = RegistryScanner();
        final skills = await scanner.scan(
          d.path('project'),
          isGlobal: false,
          repos: [registryRepo],
        );

        expect(skills, hasLength(2));
        expect(
          skills.map((s) => s.basename).toSet(),
          equals({'my_pkg-buttons', 'my_pkg-forms'}),
        );
        for (final s in skills) {
          expect(s.packageName, equals('my_pkg'));
          expect(s.skillPath, contains(p.join('skills', s.basename)));
        }
      },
    );

    test(
      'when scanning groupedByPackage layout then returns ScannedSkills',
      () async {
        const registryRepo = RegistryRepo(
          cloneUrl: 'https://github.com/owner/repo.git',
        );
        await d.dir('project', [
          d.dir('.dart_tool', [
            d.dir('skills', [
              d.dir('repos', [
                d.dir(registryRepo.pathSegment, [
                  d.dir('skills', [
                    d.dir('riverpod', [
                      skillDir('riverpod-get-started'),
                      skillDir('riverpod-testing'),
                    ]),
                    d.dir('flutter_riverpod', [
                      skillDir('flutter_riverpod-hooks'),
                    ]),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ]).create();

        const scanner = RegistryScanner();
        final skills = await scanner.scan(
          d.path('project'),
          isGlobal: false,
          repos: [registryRepo],
        );

        expect(skills, hasLength(3));
        expect(
          skills.map((s) => s.packageName).toSet(),
          equals({'riverpod', 'flutter_riverpod'}),
        );
        expect(
          skills.map((s) => s.basename).toSet(),
          equals({
            'riverpod-get-started',
            'riverpod-testing',
            'flutter_riverpod-hooks',
          }),
        );
      },
    );

    test('when skill dir has no hyphen then skipped in flat layout', () async {
      await d.dir('project', [
        d.dir('.dart_tool', [
          d.dir('skills', [
            d.dir('repos', [
              d.dir('a', [
                d.dir('b', [
                  d.dir('skills', [skillDir('no_hyphen')]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]).create();

      const scanner = RegistryScanner();
      final skills = await scanner.scan(
        d.path('project'),
        isGlobal: false,
        repos: [const RegistryRepo(cloneUrl: 'https://github.com/a/b.git')],
      );
      expect(skills, isEmpty);
    });

    test('when skill dir has no SKILL.md then skipped', () async {
      await d.dir('project', [
        d.dir('.dart_tool', [
          d.dir('skills', [
            d.dir('repos', [
              d.dir('a', [
                d.dir('b', [
                  d.dir('skills', [
                    d.dir('pkg-skill', [d.file('README.md', 'not a skill')]),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]).create();

      const scanner = RegistryScanner();
      final skills = await scanner.scan(
        d.path('project'),
        isGlobal: false,
        repos: [const RegistryRepo(cloneUrl: 'https://github.com/a/b.git')],
      );
      expect(skills, isEmpty);
    });

    test('when multiple repos then aggregates skills from all', () async {
      const registryRepos = [
        RegistryRepo(cloneUrl: 'https://github.com/owner1/repo1.git'),
        RegistryRepo(cloneUrl: 'https://github.com/owner2/repo2.git'),
      ];
      await d.dir('project', [
        d.dir('.dart_tool', [
          d.dir('skills', [
            d.dir('repos', [
              d.dir(registryRepos[0].pathSegment, [
                d.dir('skills', [skillDir('pkg-a')]),
              ]),
              d.dir(registryRepos[1].pathSegment, [
                d.dir('skills', [skillDir('pkg-b')]),
              ]),
            ]),
          ]),
        ]),
      ]).create();

      const scanner = RegistryScanner();
      final skills = await scanner.scan(
        d.path('project'),
        isGlobal: false,
        repos: registryRepos,
      );
      expect(skills, hasLength(2));
      expect(skills.map((s) => s.packageName).toSet(), equals({'pkg'}));
      expect(skills.map((s) => s.basename).toSet(), equals({'pkg-a', 'pkg-b'}));
    });

    test('when flat layout has internal skill then it is skipped', () async {
      const registryRepo = RegistryRepo(
        cloneUrl: 'https://github.com/owner/repo.git',
      );
      await d.dir('project', [
        d.dir('.dart_tool', [
          d.dir('skills', [
            d.dir('repos', [
              d.dir(registryRepo.pathSegment, [
                d.dir('skills', [
                  skillDir('my_pkg-public'),
                  skillDir(
                    'my_pkg-private',
                    extraFrontMatter: '''metadata:
  internal: true''',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]).create();

      const scanner = RegistryScanner();
      final skills = await scanner.scan(
        d.path('project'),
        isGlobal: false,
        repos: [registryRepo],
      );

      expect(skills, hasLength(1));
      expect(skills.first.basename, equals('my_pkg-public'));
      expect(skills.first.frontmatter.isInternal, isFalse);
    });

    test(
      'when groupedByPackage layout has internal skill then it is skipped',
      () async {
        const registryRepo = RegistryRepo(
          cloneUrl: 'https://github.com/owner/repo.git',
        );
        await d.dir('project', [
          d.dir('.dart_tool', [
            d.dir('skills', [
              d.dir('repos', [
                d.dir(registryRepo.pathSegment, [
                  d.dir('skills', [
                    d.dir('riverpod', [
                      skillDir('riverpod-public'),
                      skillDir(
                        'riverpod-private',
                        extraFrontMatter: '''metadata:
  internal: true''',
                      ),
                    ]),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ]).create();

        const scanner = RegistryScanner();
        final skills = await scanner.scan(
          d.path('project'),
          isGlobal: false,
          repos: [registryRepo],
        );

        expect(skills, hasLength(1));
        expect(skills.first.packageName, equals('riverpod'));
        expect(skills.first.basename, equals('riverpod-public'));
      },
    );
  });
}
