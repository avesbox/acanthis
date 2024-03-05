import '../exceptions/validation_error.dart';
import 'types.dart';

class AcanthisStringTypeDef extends AcanthisTypeDef {
  const AcanthisStringTypeDef();
}

class AcanthisString extends AcanthisType<String, AcanthisStringTypeDef> {

  AcanthisString({
    required super.definition
  });

  @override
  AcanthisParseStatus<String> parse(String value) {
    for (var check in checks) {
      if(!check.check(value)){
        throw ValidationError(
          check.error
        );
      }
    }
    return AcanthisParseStatus(
      value: value
    );
  }

  @override
  AcanthisParseStatus<String> tryParse(String value) {
    final errors = <String, String>{};
    for (var check in checks) {
      if(!check.check(value)){
        errors[check.name] = check.error;
      }
    }
    return AcanthisParseStatus(
      value: value,
      errors: errors,
      success: errors.isEmpty
    );
  }

  AcanthisString email(){
    addCheck(AcanthisCheck<String>(
      onCheck: (value) => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value),
      error: 'Invalid email format',
      name: 'email'
    ));
    return this;
  }

  AcanthisString min(int length){
    addCheck(AcanthisCheck<String>(
      onCheck: (value) => value.length >= length,
      error: 'Value must be at least $length characters long',
      name: 'min'
    ));
    return this;
  }

  AcanthisString max(int length){
    addCheck(AcanthisCheck<String>(
      onCheck: (value) => value.length <= length,
      error: 'Value must be at most $length characters long',
      name: 'maxLength'
    ));
    return this;
  }

  AcanthisString pattern(RegExp pattern){
    addCheck(AcanthisCheck<String>(
      onCheck: (value) => pattern.hasMatch(value),
      error: 'Value does not match the pattern',
      name: 'pattern'
    ));
    return this;
  }

  AcanthisString required(){
    addCheck(AcanthisCheck<String>(
      onCheck: (value) => value.isNotEmpty,
      error: 'Value is required',
      name: 'required'
    ));
    return this;
  }

  AcanthisString length(int length){
    addCheck(AcanthisCheck<String>(
      onCheck: (value) => value.length == length,
      error: 'Value cannot be empty',
      name: 'notEmpty'
    ));
    return this;
  }

  AcanthisString contains(String value){
    addCheck(AcanthisCheck<String>(
      onCheck: (v) => v.contains(value),
      error: 'Value must contain $value',
      name: 'contains'
    ));
    return this;
  }

  AcanthisString startsWith(String value){
    addCheck(AcanthisCheck<String>(
      onCheck: (v) => v.startsWith(value),
      error: 'Value must start with $value',
      name: 'startsWith'
    ));
    return this;
  }

  AcanthisString endsWith(String value){
    addCheck(AcanthisCheck<String>(
      onCheck: (v) => v.endsWith(value),
      error: 'Value must end with $value',
      name: 'endsWith'
    ));
    return this;
  }

}

AcanthisString string() => AcanthisString(definition: const AcanthisStringTypeDef());