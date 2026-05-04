import 'dart:async';

import 'package:io/io.dart';

/// The shared instance of [SharedStdIn] for the current [Zone].
///
/// This will error if not running inside a [withSharedStdin] callback.
//
// ignore: invalid_use_of_visible_for_testing_member
SharedStdIn get sharedStdIn => Zone.current[SharedStdIn] as SharedStdIn;

T withSharedStdin<T>(
  // ignore: invalid_use_of_visible_for_testing_member
  SharedStdIn sharedStdin,
  T Function() fn,
) =>
    runZoned(
      fn,
      zoneValues: {
        // ignore: invalid_use_of_visible_for_testing_member
        SharedStdIn: sharedStdin,
      },
    );
