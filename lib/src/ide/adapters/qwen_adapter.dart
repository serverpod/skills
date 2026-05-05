import '../ide.dart';
import 'agent_skills_adapter.dart';

/// Qwen Code adapter.
///
/// Installs skills to `.qwen/skills/<skill-name>/` per
/// [Qwen Code skills](https://qwenlm.github.io/qwen-code-docs/en/users/features/skills/).
class QwenAdapter extends AgentSkillsAdapter {
  QwenAdapter(String projectPath) : super(Ide.qwen.skillsPath(projectPath));
}
