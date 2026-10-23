import '../common/issue.dart' show singleIssueParameter;
import '../common/operations.dart';

final class ExactCheck<T> implements Check<T> {
  ExactCheck({required this.value})
    : parameters = singleIssueParameter('value', value);
  final T value;
  final Map<String, Object?> parameters;

  @override
  void evaluate(T value, CheckContext context) {
    if (value != this.value) context.addIssue('exact', parameters: parameters);
  }
}
