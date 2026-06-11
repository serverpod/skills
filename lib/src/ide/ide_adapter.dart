import 'package:logging/logging.dart';

import '../core/skill_scanner.dart';

import 'ide.dart';

/// Abstract interface for IDE-specific skill installation and removal.
abstract class IdeAdapter {
  final Ide ide;

  IdeAdapter(this.ide);

  /// Installs a skill from the scanned location into the IDE's directory.
  ///
  /// Returns the skill name as installed and its content hash (if any).
  Future<InstallSkillResult> installSkill(ScannedSkill skill);

  /// A logger for this IDE Adapter. Should contain the name of the IDE.
  Logger get logger;

  /// Removes a previously installed skill by its name.
  ///
  /// If [originalHash] is provided, then it will check the current hash of the
  /// directory and prompt the user if they want to overwrite it, if there have
  /// been any manual changes since it was installed. If we do not have dialog
  /// support then it will log a warning advertising the `--force` flag and
  /// return `false`.
  ///
  /// Returns `true` if removed successfully or it didn't exist.
  /// Returns `false` if the user aborted the removal.
  Future<bool> removeSkill(String skillName);

  /// Returns the absolute path to the IDE's skills/rules directory.
  String get skillsDirectory;

  /// Creates the skills directory if it doesn't exist.
  Future<void> ensureSkillsDirectory();
}

/// The result type for [IdeAdapter.installSkill].
typedef InstallSkillResult = ({String name, String contentHash});

/// Helper method to prompt the user if they want to overwrite a skill that has
/// been modified locally since it was installed.
///
/// Returns `true` if the user approves it, [originalHash] was null, or the
/// hashes were equal.
