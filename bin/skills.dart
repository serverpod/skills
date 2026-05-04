import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:cli_util/windows_compatibility.dart';
import 'package:io/io.dart';
import 'package:skills/src/commands/get_command.dart';
import 'package:skills/src/commands/list_command.dart';
import 'package:skills/src/commands/prune_command.dart';
import 'package:skills/src/commands/remove_command.dart';
import 'package:skills/src/core/stdin.dart';

Future<void> main(List<String> arguments) async {
  final stdin =
      SharedStdIn(io.Platform.isWindows ? Win32AnsiStdin() : io.stdin);
  try {
    await withSharedStdin(stdin, () async {
      final runner = CommandRunner<void>(
        'skills',
        'Manage AI agent skills for Dart/Flutter packages.',
      )
        ..addCommand(GetCommand())
        ..addCommand(ListCommand())
        ..addCommand(PruneCommand())
        ..addCommand(RemoveCommand());

      try {
        await runner.run(arguments);
      } on UsageException catch (e) {
        print(e);
      }
    });
  } finally {
    await stdin.terminate();
  }
}
