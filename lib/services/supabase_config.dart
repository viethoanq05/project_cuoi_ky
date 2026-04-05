class SupabaseConfig {
  SupabaseConfig._();

  static final SupabaseConfig instance = SupabaseConfig._();

  late final String url;
  late final String anonKey;
  late final String storageBucket;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  void load({
    required String url,
    required String anonKey,
    String storageBucket = 'food-images',
  }) {
    if (_isInitialized) {
      return;
    }
    this.url = url;
    this.anonKey = anonKey;
    this.storageBucket = storageBucket.isNotEmpty ? storageBucket : 'food-images';
    _isInitialized = true;
  }
}
