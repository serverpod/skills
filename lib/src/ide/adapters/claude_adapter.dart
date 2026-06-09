import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/dialog_support.dart';
import '../../core/hash_utils.dart';
import '../../core/skill_scanner.dart';
import '../ide.dart';
import 'agent_skills_adapter.dart';

/// Claude Code adapter.
///
/// Installs skills to `.claude/skills/<skill-name>/` per
/// [Claude Code skills](https://code.claude.com/docs/en/skills).
class ClaudeAdapter extends AgentSkillsAdapter {
  @override
  final Logger logger = Logger('ClaudeAdapter');

  ClaudeAdapter(String projectPath, [DialogSupport? dialogSupport])
      : super(Ide.claude.skillsPath(projectPath), dialogSupport);

  @override
  Future<({String name, String? contentHash})> installSkill(
    ScannedSkill skill,
  ) async {
    var result = await super.installSkill(skill);

    final targetDir = Directory(p.join(skillsDirectory, skill.skillName));
    final skillMd = File(p.join(targetDir.path, 'SKILL.md'));

    if (await skillMd.exists()) {
      var content = await skillMd.readAsString();
      if (!content.contains('user-invocable:')) {
        final closingIndex = content.indexOf('---', 3);
        if (closingIndex != -1) {
          content = '${content.substring(0, closingIndex)}'
              'user-invocable: false\n'
              '${content.substring(closingIndex)}';
          await skillMd.writeAsString(content);

          // Re-calculate hash since we modified the file
          final hash = await tryCalculateDirectoryHash(targetDir);
          result = (name: result.name, contentHash: hash);
        }
      }
    }

    return result;
  }
}
