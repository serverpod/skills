import '../ide.dart';
import 'agent_skills_adapter.dart';

/// Qoder adapter.
///
/// Installs skills to `.qoderwork/skills/<skill-name>/` per
/// [Qoder skills](https://docs.qoder.com/qoderwork/skills).
class QoderAdapter extends AgentSkillsAdapter {
  QoderAdapter(String projectPath) : super(Ide.qoder.skillsPath(projectPath));
}
