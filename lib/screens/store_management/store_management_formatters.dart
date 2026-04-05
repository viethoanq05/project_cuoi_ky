String formatStoreCurrency(double value) {
  final rounded = value.round();
  final raw = rounded.toString();
  final digits = raw.split('');
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remain = digits.length - i - 1;
    if (remain > 0 && remain % 3 == 0) {
      buffer.write(',');
    }
  }

  return '${buffer.toString()} VND';
}
