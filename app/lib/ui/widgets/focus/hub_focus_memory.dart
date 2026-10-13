class HubFocusMemory {
  static final Map<String, int> _store = {};

  static int getForHub(String key, int itemCount) {
    if (itemCount <= 0) return 0;
    final stored = _store[key] ?? 0;
    return stored.clamp(0, itemCount - 1);
  }

  static int? peek(String key) => _store[key];

  static void set(String key, int index) {
    if (index < 0) return;
    _store[key] = index;
  }

  static void clear(String key) => _store.remove(key);

  static void clearAll() => _store.clear();
}
