import 'dart:collection';

class RollingSampleBuffer<T extends num> {
  factory RollingSampleBuffer({required int capacity}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be greater than 0');
    }
    return RollingSampleBuffer<T>._(capacity);
  }

  RollingSampleBuffer._(this.capacity);

  final int capacity;
  final List<T> _storage = <T>[];

  int _start = 0;
  int _revision = 0;
  int _sortedRevision = -1;
  List<T>? _cachedSortedValues;

  int get length => _storage.length;
  bool get isEmpty => _storage.isEmpty;

  void add(T value) {
    if (_storage.length < capacity) {
      _storage.add(value);
    } else {
      _storage[_start] = value;
      _start = (_start + 1) % capacity;
    }
    _markDirty();
  }

  List<T> sortedValues() {
    final cached = _cachedSortedValues;
    if (cached != null && _sortedRevision == _revision) {
      return cached;
    }

    final values = List<T>.generate(
      _storage.length,
      (index) => _storage[(_start + index) % _storage.length],
      growable: false,
    )..sort((left, right) => left.compareTo(right));
    final immutable = UnmodifiableListView<T>(values);
    _cachedSortedValues = immutable;
    _sortedRevision = _revision;
    return immutable;
  }

  void clear() {
    if (_storage.isEmpty) {
      return;
    }
    _storage.clear();
    _start = 0;
    _markDirty();
  }

  void _markDirty() {
    _revision++;
    _cachedSortedValues = null;
  }
}
