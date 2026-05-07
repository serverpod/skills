import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:cli_util/windows_compatibility.dart';
import 'package:io/io.dart';
import 'package:skills/src/commands/get_command.dart';
import 'package:skills/src/commands/list_command.dart';
import 'package:skills/src/commands/prune_command.dart';
import 'package:skills/src/commands/remove_command.dart';
import 'package:skills/src/core/cli_dialog_support.dart';

Future<void> main(List<String> arguments) async {
  final sharedStdin =
      SharedStdIn(io.Platform.isWindows ? Win32AnsiStdin() : io.stdin);
  final dialogSupport = CliDialogSupport(sharedStdin);
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
    await sharedStdin.terminate();
  }
}
