import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/core/git_repos.dart';
import 'package:skills/src/models/skill_manifest.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

  group('GitRepo', () {
    test('pathSegment encodes cloneUrl', () {
      const repo = GitRepo(cloneUrl: 'https://github.com/flutter/skills.git');
      expect(
        repo.pathSegment,
        equals(Uri.encodeComponent('https://github.com/flutter/skills.git')),
      );
    });
  });

  group('gitReposPath / gitRepoPath', () {
    test('gitReposPath includes .dart_tool/skills/repos', () {
      final path = gitReposPath('/project');
      expect(path, contains(p.join(SkillManifest.cacheDirPath, 'repos')));
    });

    test('gitRepoPath includes host, owner and repo', () {
      const repo = GitRepo(cloneUrl: 'https://github.com/flutter/skills.git');
      final path = gitRepoPath('/project', repo);
      expect(
        path,
        contains(
          p.join(
            SkillManifest.cacheDirPath,
            'repos',
            Uri.encodeComponent(repo.cloneUrl),
          ),
        ),
      );
    });
  });
}
