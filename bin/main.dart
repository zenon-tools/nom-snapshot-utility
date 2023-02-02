import 'dart:async';

import 'config/config.dart';
import 'handlers/apr_handler.dart';
import 'handlers/pillar_handler.dart';

main(List<String> arguments) {
  Config.load();
  print('Starting');

  final pillarHandler = PillarHandler();
  pillarHandler.init();
  pillarHandler.run();

  final aprHandler = AprHandler();
  aprHandler.init();
  aprHandler.run();

  _run(pillarHandler);
  _run(aprHandler);
}

_run(final handler) {
  Timer.periodic(Duration(seconds: 30), (Timer t) {
    t.cancel();
    final stopwatch = Stopwatch()..start();
    handler.run();
    //print('run() executed in ${stopwatch.elapsed.inMilliseconds} msecs');
    stopwatch.stop();
    _run(handler);
  });
}
