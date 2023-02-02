import 'dart:convert';
import 'dart:io';

import '../config/config.dart';

class AprHandler {
  final dataStoreDir = '${Directory.current.path}/data_store';

  AprHandler();

  init() {
    Directory('${dataStoreDir}/apr/snapshots').createSync(recursive: true);
    Directory('${dataStoreDir}/apr/statistics').createSync(recursive: true);
  }

  run() {
    final midnight = _getLastMidnight();
    if (_shouldTakeSnapshot(midnight)) {
      print(
          'Taking APR snapshot at ${DateTime.now().toUtc().toIso8601String()}');
      _saveAprSnapshot(midnight);
      _updateAprHistory(midnight, 30);
      _updateAprHistory(midnight, 90);
      _updateAprHistory(midnight, 180);
      _updateAprHistory(midnight, 360);
    }
  }

  bool _shouldTakeSnapshot(int lastMidnight) {
    final snapshotExists =
        File('${dataStoreDir}/apr/snapshots/$lastMidnight.json').existsSync();
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

  _saveAprSnapshot(int timestamp) {
    final dataFile = File('${Config.refinerDataStoreDirectory}/nom_data.json');
    dataFile.copySync('${dataStoreDir}/apr/snapshots/$timestamp.json');
  }

  _updateAprHistory(int lastSnapshotTime, int lengthInDays) {
    const secsPerDay = 86400;

    List<Map<String, dynamic>> snapshots = [];
    for (int i = 0; i < lengthInDays; i++) {
      final timestamp = lastSnapshotTime - i * secsPerDay;
      final snapshotPath = '${dataStoreDir}/apr/snapshots/$timestamp.json';
      if (File(snapshotPath).existsSync()) {
        snapshots.add(jsonDecode(File(snapshotPath).readAsStringSync())
            as Map<String, dynamic>);
      }
    }

    if (snapshots.isEmpty) {
      return;
    }

    Map<String, dynamic> history = {};

    num stakingApr = 0;
    num delegateApr = 0;
    num lpApr = 0;
    num sentinelApr = 0;
    num pillarAprTop30 = 0;
    num pillarAprNotTop30 = 0;

    for (final snap in snapshots) {
      stakingApr += snap['stakingApr'] as num;
      delegateApr += snap['delegateApr'] as num;
      lpApr += snap['lpApr'] as num;
      sentinelApr += snap['sentinelApr'] as num;
      pillarAprTop30 += snap['pillarAprTop30'] as num;
      pillarAprNotTop30 += snap['pillarAprNotTop30'] as num;
    }

    if (snapshots.length > 0) {
      history = {
        'avgStakingApr': stakingApr / snapshots.length,
        'avgDelegateApr': delegateApr / snapshots.length,
        'avgLpApr': lpApr / snapshots.length,
        'avgSentinelApr': sentinelApr / snapshots.length,
        'avgPillarAprTop30': pillarAprTop30 / snapshots.length,
        'avgPillarAprNotTop30': pillarAprNotTop30 / snapshots.length
      };
    }

    if (history.isNotEmpty) {
      File('${dataStoreDir}/apr/statistics/${lengthInDays}d.json')
          .writeAsStringSync(JsonEncoder.withIndent('  ').convert(history));
    }
  }
}
