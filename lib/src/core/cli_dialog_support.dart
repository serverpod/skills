// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:cli_util/cli_components.dart' as cli;
import 'package:io/io.dart';
import 'dialog_support.dart';

/// Implementation of [DialogSupport] using `package:cli_util`.
class CliDialogSupport implements DialogSupport {
  // ignore: invalid_use_of_visible_for_testing_member
  final SharedStdIn _sharedStdIn;

  CliDialogSupport(this._sharedStdIn);

  @override
  Future<int?> showSingleSelectDialog(List<String> options) {
    return cli.showSingleSelectDialog(options, _sharedStdIn);
  }

  @override
  Future<Set<int>?> showMultiSelectDialog(List<String> options) {
    return cli.showMultiSelectDialog(options, _sharedStdIn);
  }
}
