import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:cli_util/windows_compatibility.dart';
import 'package:io/io.dart';
import 'package:skills/skills.dart';
import 'package:skills/src/commands/prune_command.dart';
import 'package:skills/src/core/cli_dialog_support.dart';

Future<void> main(List<String> arguments) async {
  DialogSupport? dialogSupport;
  // TODO: Remove this when https://github.com/dart-lang/tools/pull/2396
  // is release.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedStdIn? sharedStdIn;
  if (io.stdin.hasTerminal && io.stdout.hasTerminal) {
    sharedStdIn =
        SharedStdIn(io.Platform.isWindows ? Win32AnsiStdin() : io.stdin);
    dialogSupport = CliDialogSupport(sharedStdIn);
  }
  try {
    final runner = CommandRunner<void>(
      'skills',
      'Manage AI agent skills for Dart/Flutter packages.',
    )
      ..addCommand(GetCommand(dialogSupport: dialogSupport))
      ..addCommand(ListCommand())
      ..addCommand(PruneCommand(dialogSupport: dialogSupport))
      ..addCommand(RemoveCommand(dialogSupport: dialogSupport));

    try {
      await runner.run(arguments);
    } on UsageException catch (e) {
      print(e);
    }
  } finally {
    await sharedStdIn?.terminate();
  }
}
