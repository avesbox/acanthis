class TestObject {
  final String id;
  final String name;

  TestObject({required this.id, required this.name});
}

abstract class TestVariant {}

class TestVariantA extends TestVariant {
  final String value;

  TestVariantA(this.value);
}

class TestVariantB extends TestVariant {
  final int value;

  TestVariantB(this.value);
}
