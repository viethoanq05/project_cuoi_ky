class ApiConfig {
  static const bankbaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.10/Bank/public/api',
  );
}