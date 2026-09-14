---
layout: page
sidebar: false
title: Data validation for Dart & Flutter
description: Describe, validate, and transform data with Acanthis. Clear schemas and useful errors for Dart and Flutter.
head:
  - - meta
    - property: og:image
      content: https://acanthis.dev/acanthis-banner.png
---

<script setup>
import Home from './components/hero.vue'
</script>

<Home>
<template #example>

```dart
import 'package:acanthis/acanthis.dart';

final account = object({
  'name': string().min(2),
  'email': string().email(),
});

final result = account.tryParse({
  'name': 'Ada',
  'email': 'ada@example.com',
});

print(result.success); // true
print(result.value['name']); // Ada
```

</template>
</Home>
