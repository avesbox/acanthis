import '../common/issue.dart' show singleIssueParameter;
import '../common/operations.dart';

final class EnumeratedNullableCheck<T> implements Check<T?> {
  EnumeratedNullableCheck(List<T?> values)
    : values = List.unmodifiable(values),
      parameters = singleIssueParameter('values', [...values, null]);
  final List<T?> values;
  final Map<String, Object?> parameters;
  @override
  void evaluate(T? value, CheckContext context) {
    if (value != null && !values.contains(value)) {
      context.addIssue('enumerated', parameters: parameters);
    }
  }
}
