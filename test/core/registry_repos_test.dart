import 'package:skills/src/core/registry_repos.dart';
import 'package:test/test.dart';

void main() {
  group('RegistryRepo', () {
    test('pathSegment encodes cloneUrl', () {
      const repo = RegistryRepo(
        cloneUrl: 'https://github.com/flutter/skills.git',
      );
      expect(repo.pathSegment,
          equals(Uri.encodeComponent('https://github.com/flutter/skills.git')));
    });

    test('cloneUrl is the provided URL', () {
      const repo = RegistryRepo(
        cloneUrl: 'https://example.com/repo.git',
      );
      expect(
        repo.cloneUrl,
        equals('https://example.com/repo.git'),
      );
    });
  });

  group('registryReposPath / registryRepoPath', () {
    test('registryReposPath ends with .dart_skills/repos', () {
      final path = registryReposPath('/project');
      expect(path, contains('.dart_skills'));
      expect(path, contains('repos'));
    });

    test('registryRepoPath includes host, owner and repo', () {
      const repo = RegistryRepo(
        cloneUrl: 'https://github.com/flutter/skills.git',
      );
      final path = registryRepoPath('/project', repo);
      expect(path, contains('.dart_skills'));
      expect(path, contains('github.com'));
      expect(path, contains('flutter'));
      expect(path, contains('skills'));
    });
  });
}
