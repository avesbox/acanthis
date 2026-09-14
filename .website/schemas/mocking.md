---
description: Generate sample input and choose between legacy mocking and bounded seeded generation.
---

# Mock data

Generate sample input and choose between legacy mocking and bounded seeded generation.

## Mocking schemas

Use `mock()` for best-effort sample data. It does not guarantee that the generated value passes validation. For bounded generation that validates every returned value, use [seeded mocking](/seeded-mocking).

```dart
final userSchema = object({
  'name': string().min(3),
  'age': number().positive(),
  'email': string().email(),
});
final mockUser = userSchema.mock();

print(mockUser);
// => { name: 'Acanthis', age: 32, email: 'test@example.com' }
```

## Seeded test data

Use [`mockSeeded`](/seeded-mocking) for bounded, reproducible generation with a documented supported subset and a validation guarantee.

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
