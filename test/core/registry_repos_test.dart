import 'package:path/path.dart' as p;

import 'package:skills/src/core/registry_repos.dart';
import 'package:test/test.dart';

void main() {
  group('RegistryRepo', () {
    test('pathSegment joins owner and name', () {
      const repo = RegistryRepo(
        owner: 'flutter',
        name: 'skills',
      );
      expect(repo.pathSegment, equals(p.join('flutter', 'skills')));
    });

    test('cloneUrl is https github URL', () {
      const repo = RegistryRepo(
        owner: 'serverpod',
        name: 'skills-registry',
      );
      expect(
        repo.cloneUrl,
        equals('https://github.com/serverpod/skills-registry.git'),
      );
    });
  });

  group('registryReposPath / registryRepoPath', () {
    test('registryReposPath ends with .dart_skills/repos', () {
      final path = registryReposPath('/project');
      expect(path, contains('.dart_skills'));
      expect(path, contains('repos'));
    });

    test('registryRepoPath includes owner and repo', () {
      const repo = RegistryRepo(
        owner: 'flutter',
        name: 'skills',
      );
      final path = registryRepoPath('/project', repo);
      expect(path, contains('.dart_skills'));
      expect(path, contains('flutter'));
      expect(path, contains('skills'));
    });
  });
}
