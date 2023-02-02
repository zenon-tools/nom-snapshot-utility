import 'dart:convert';
import 'dart:io';

import '../config/config.dart';

class PillarHandler {
  final dataStoreDir = '${Directory.current.path}/data_store';

  PillarHandler();

  init() {
    Directory('${dataStoreDir}/pillars/snapshots').createSync(recursive: true);
    Directory('${dataStoreDir}/pillars/statistics').createSync(recursive: true);
  }

  run() {
    final midnight = _getLastMidnight();
    if (_shouldTakeSnapshot(midnight)) {
      print(
          'Taking pillar snapshot at ${DateTime.now().toUtc().toIso8601String()}');
      _savePillarsSnapshot(midnight);
      _updatePillarHistory(midnight, 30);
      _updatePillarHistory(midnight, 90);
      _updatePillarHistory(midnight, 180);
      _updatePillarHistory(midnight, 360);
    }
  }

  bool _shouldTakeSnapshot(int lastMidnight) {
    final snapshotExists =
        File('${dataStoreDir}/pillars/snapshots/$lastMidnight.json')
            .existsSync();
    final now = DateTime.now().toUtc();
    final snapshotWindowStart =
        (DateTime.utc(now.year, now.month, now.day, 11, 59));
    final snapshotWindowEnd = (DateTime.utc(now.year, now.month, now.day, 12));
    return !snapshotExists &&
        now.compareTo(snapshotWindowStart) >= 0 &&
        now.compareTo(snapshotWindowEnd) < 0;
  }

  int _getLastMidnight() {
    final now = DateTime.now().toUtc();
    return (DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch /
            1000)
        .round();
  }

  _savePillarsSnapshot(int timestamp) {
    final dataFile =
        File('${Config.refinerDataStoreDirectory}/pillar_data.json');
    dataFile.copySync('${dataStoreDir}/pillars/snapshots/$timestamp.json');
  }

  _updatePillarHistory(int lastSnapshotTime, int lengthInDays) {
    const secsPerDay = 86400;

    List<Map<String, dynamic>> snapshots = [];
    for (int i = 0; i < lengthInDays; i++) {
      final timestamp = lastSnapshotTime - i * secsPerDay;
      final snapshotPath = '${dataStoreDir}/pillars/snapshots/$timestamp.json';
      if (File(snapshotPath).existsSync()) {
        snapshots.add(jsonDecode(File(snapshotPath).readAsStringSync())
            as Map<String, dynamic>);
      }
    }

    if (snapshots.isEmpty) {
      return;
    }

    final pillars = (jsonDecode(
            File('${dataStoreDir}/pillars/snapshots/$lastSnapshotTime.json')
                .readAsStringSync()) as Map<String, dynamic>)
        .keys
        .toList();

    Map<String, dynamic> history = {};

    for (final pillar in pillars) {
      int totalProduced = 0;
      int totalExpected = 0;
      num totalDelegateApr = 0;
      int snapshotCount = 0;

      for (final snap in snapshots) {
        if (snap.containsKey(pillar)) {
          final expected = snap[pillar]['expectedMomentums'] as int;
          final produced = snap[pillar]['producedMomentums'] as int;
          // Give leeway of one momentum because of inaccuracy of snapshot.
          totalExpected += produced < expected ? expected - 1 : expected;
          totalProduced += produced;
          totalDelegateApr += snap[pillar]['delegateApr'] as num;
          snapshotCount++;
        }
      }

      if (snapshotCount > 0) {
        final avgDelegateApr = totalDelegateApr / snapshotCount;
        history[pillar] = {
          'totalProduced': totalProduced,
          'totalExpected': totalExpected,
          'uptime': totalProduced / totalExpected,
          'avgDelegateApr': avgDelegateApr,
          'snapshotCount': snapshotCount
        };
      }
    }

    if (history.isNotEmpty) {
      File('${dataStoreDir}/pillars/statistics/${lengthInDays}d.json')
          .writeAsStringSync(JsonEncoder.withIndent('  ').convert(history));
    }
  }
}
