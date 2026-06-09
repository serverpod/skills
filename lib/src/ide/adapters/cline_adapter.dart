import 'package:logging/logging.dart';

import '../../core/dialog_support.dart';
import '../ide.dart';
import 'agent_skills_adapter.dart';

/// Cline adapter (experimental).
///
/// Installs skills to `.cline/skills/<skill-name>/` per
/// [Cline skills](https://docs.cline.bot/customization/skills).
class ClineAdapter extends AgentSkillsAdapter {
  @override
  final Logger logger = Logger('ClineAdapter');

  ClineAdapter(String projectPath, [DialogSupport? dialogSupport])
      : super(Ide.cline.skillsPath(projectPath), dialogSupport);
}
