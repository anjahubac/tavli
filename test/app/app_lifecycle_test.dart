import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/app.dart';

void main() {
  test('realtime pauses only when the window is hidden or paused', () {
    expect(isVisibleLifecycle(null), isTrue);
    expect(isVisibleLifecycle(AppLifecycleState.resumed), isTrue);
    // Desktop window without focus / Android split screen.
    expect(isVisibleLifecycle(AppLifecycleState.inactive), isTrue);
    expect(isVisibleLifecycle(AppLifecycleState.hidden), isFalse);
    expect(isVisibleLifecycle(AppLifecycleState.paused), isFalse);
  });
}
