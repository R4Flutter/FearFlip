class ObjectPool<T> {
  ObjectPool({required T Function() create}) : _create = create;

  final T Function() _create;
  final List<T> _free = <T>[];

  T acquire() {
    if (_free.isEmpty) {
      return _create();
    }
    return _free.removeLast();
  }

  void release(T item) {
    _free.add(item);
  }
}
