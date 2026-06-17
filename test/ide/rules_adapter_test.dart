import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/core/hash_utils.dart';
import 'package:skills/src/ide/adapters/rules_adapter.dart';
import 'package:skills/src/ide/ide.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  setUpAll(() {
    Logger.root.onRecord.listen((r) => printOnFailure(r.toString()));
  });

  group('Given a RulesAdapter', () {
    late RulesAdapter adapter;

    setUp(() async {
      await d.dir('project', [d.dir('rules', [])]).create();

      adapter = RulesAdapter(
        Ide.cursor, // We use a fake ide since we are testing RulesAdapter base logic
        skillsDirectory: d.path('project/rules'),
      );
    });

    test('when skill exists then returns hash', () async {
      await d.dir('project', [
        d.dir('rules', [d.file('test-skill.md', 'content')]),
      ]).create();

      final targetFile = File(p.join(adapter.skillsDirectory, 'test-skill.md'));
      final expectedHash = await tryCalculateFileHash(targetFile);
      expect(
        await adapter.computeInstalledSkillHash('test-skill'),
        equals(expectedHash),
      );
    });

    test('when skill does not exist then returns null', () async {
      expect(
        await adapter.computeInstalledSkillHash('non-existent-skill'),
        isNull,
      );
    });
  });
}
