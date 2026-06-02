// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:skills/src/core/dialog_support.dart';

/// A fake implementation of [DialogSupport] for testing.
class FakeDialogSupport implements DialogSupport {
  int? singleSelectResult;
  Set<int>? multiSelectResult;

  List<Set<int>?>? multiSelectResultsList;
  int _multiSelectCallCount = 0;

  List<String>? lastSingleSelectOptions;
  List<String>? lastMultiSelectOptions;
  Set<int>? lastInitialSelected;
  String? lastTitle;

  final List<List<String>> allMultiSelectOptions = [];
  final List<Set<int>> allInitialSelected = [];
  final List<String?> allTitles = [];

  @override
  Future<int?> showSingleSelectDialog(List<String> options,
      {String? title}) async {
    lastSingleSelectOptions = options;
    return singleSelectResult;
  }

  @override
  Future<Set<int>?> showMultiSelectDialog(
    List<String> options, {
    String? title,
    Set<int> initialSelected = const {},
  }) async {
    lastMultiSelectOptions = options;
    lastInitialSelected = initialSelected;
    lastTitle = title;
    allMultiSelectOptions.add(options);
    allInitialSelected.add(initialSelected);
    allTitles.add(title);

    final list = multiSelectResultsList;
    if (list != null) {
      if (_multiSelectCallCount < list.length) {
        return list[_multiSelectCallCount++];
      }
      return null;
    }
    return multiSelectResult;
  }
}
