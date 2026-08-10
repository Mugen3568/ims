import 'package:flutter_test/flutter_test.dart';
import 'package:ims_app/core/result.dart';

void main() {
  test('Success exposes its value through when', () {
    const result = Success<int>(42);
    final value = result.when(
      success: (value) => value,
      failure: (_, __) => -1,
    );
    expect(value, 42);
  });

  test('Failure exposes its error through when', () {
    const result = Failure<int>('permission-denied');
    final value = result.when(
      success: (_) => 'success',
      failure: (error, _) => error.toString(),
    );
    expect(value, 'permission-denied');
  });
}
