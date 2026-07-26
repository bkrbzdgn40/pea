import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum ScreenAwakeOwner { preparation, liveAnalysis }

final screenAwakeControllerProvider = Provider<ScreenAwakeController>((ref) {
  final controller = ScreenAwakeController();
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

/// Keeps the screen awake while at least one camera workflow owns the policy.
///
/// Calls are serialized so a delayed release from one route cannot disable the
/// wakelock after the next route has already acquired it.
class ScreenAwakeController {
  ScreenAwakeController({Future<void> Function(bool enable)? toggle})
    : _toggle = toggle ?? _toggleSystemWakelock;

  final Future<void> Function(bool enable) _toggle;
  final Set<ScreenAwakeOwner> _owners = <ScreenAwakeOwner>{};

  Future<void> _pendingSync = Future<void>.value();
  bool _appliedEnabled = false;
  bool _disposed = false;

  Set<ScreenAwakeOwner> get owners =>
      Set<ScreenAwakeOwner>.unmodifiable(_owners);

  bool get isRequested => _owners.isNotEmpty;

  Future<void> acquire(ScreenAwakeOwner owner) {
    if (_disposed) {
      return Future<void>.value();
    }
    _owners.add(owner);
    return _scheduleSync();
  }

  Future<void> release(ScreenAwakeOwner owner) {
    _owners.remove(owner);
    return _scheduleSync();
  }

  Future<void> dispose() {
    if (_disposed) {
      return _pendingSync;
    }
    _disposed = true;
    _owners.clear();
    return _scheduleSync();
  }

  Future<void> _scheduleSync() {
    _pendingSync = _pendingSync
        .catchError((_) {
          // A platform failure must not break future ownership transitions.
        })
        .then((_) => _syncRequestedState());
    return _pendingSync;
  }

  Future<void> _syncRequestedState() async {
    final shouldEnable = _owners.isNotEmpty;
    if (_appliedEnabled == shouldEnable) {
      return;
    }

    try {
      await _toggle(shouldEnable);
      _appliedEnabled = shouldEnable;
    } catch (_) {
      // Camera workflows must remain usable when wakelock is unavailable.
    }
  }

  static Future<void> _toggleSystemWakelock(bool enable) {
    return WakelockPlus.toggle(enable: enable);
  }
}
