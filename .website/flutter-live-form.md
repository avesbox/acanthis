---
description: Connect a live session to Flutter fields, show pending state, and submit settled output.
---

# Build a Flutter live form

Connect field edits to a live session, render its issues, and submit its validated output. This complete example adds username availability and password confirmation.

After [installing Acanthis](/introduction#installation) in a compatible Flutter
project, replace `lib/main.dart` with the following. The availability and submit
services are simulated with delayed Futures, so the example needs no backend.
`admin` is unavailable; passwords must contain at least eight characters.

```dart
import 'package:acanthis/acanthis.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: SignupPage()));

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  AcanthisAsyncLiveSession? _session;
  bool _busy = true;
  bool _saving = false;
  String? _error;
  int _edit = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final schema = object({
        'username': string().min(3).refineAsync(CallbackAsyncCheck(
          (value, context) async {
            // Demo service. Replace with your availability API.
            await Future<void>.delayed(const Duration(milliseconds: 300));
            if (value.toLowerCase() == 'admin') context.addIssue('available');
          },
        )),
        'password': string().min(8),
        'confirmation': string(),
      }).checkFields(
        ['password', 'confirmation'],
        at: 'confirmation',
        name: 'passwordMismatch',
        error: 'Passwords do not match',
        check: (fields) => fields['password'] == fields['confirmation'],
      );
      final session = await schema.watchAsync(
        {'username': '', 'password': '', 'confirmation': ''},
        debounce: const Duration(milliseconds: 200),
        scope: AcanthisValidationScope(
          fieldPolicy: AcanthisCollectionPolicy.first,
        ),
      );
      if (!mounted) {
        session.dispose();
        return;
      }
      setState(() {
        _session = session;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not initialize validation. Try again.';
      });
    }
  }

  Future<void> _change(String field, String value) async {
    final session = _session!;
    final edit = ++_edit;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final delta = await session.set(field, value);
      if (!mounted || edit != _edit) return;
      if (!delta.isCurrent || !delta.settled ||
          delta.revision != session.revision) {
        return;
      }
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted || edit != _edit) return;
      setState(() {
        _busy = false;
        _error = 'Validation failed unexpectedly. Edit a field to retry.';
      });
    }
  }

  Future<void> _submit() async {
    final values = _session?.validated;
    if (_busy || _saving || _error != null || values == null) return;
    // Capture a valid snapshot before awaiting the request.
    final payload = {
      'username': values['username'] as String,
      'password': values['password'] as String,
    };
    setState(() => _saving = true);
    try {
      // Demo submission. Replace with your account-creation API.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo submitted for ${payload['username']}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final catalog = AcanthisMessageCatalogs.english.extend({
      'available': (_) => 'Username is unavailable',
    });
    final errors = session?.issues.formatFields(catalog: catalog) ?? <String, List<String>>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy || _saving) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (session == null && !_busy)
              TextButton(onPressed: _initialize, child: const Text('Retry')),
            if (session != null) ...[
              for (final field in ['username', 'password', 'confirmation'])
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    enabled: !_saving,
                    obscureText: field != 'username',
                    autocorrect: false,
                    enableSuggestions: field == 'username',
                    onChanged: (value) => _change(field, value),
                    decoration: InputDecoration(
                      labelText: field,
                      errorText: _busy ? null : errors['/$field']?.first,
                      helperText: _busy ? 'Checking changes…' : null,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: !_busy && !_saving && _error == null &&
                        session.validated != null
                    ? _submit
                    : null,
                child: const Text('Create account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

```

## Render validation state

`TextField.onChanged` sends raw edits to the session. Structured issues are
rendered with `InputDecoration.errorText`, which also lets async failures appear
without a synchronous `FormField.validator` callback.

The page displays initial field failures once initialization settles.
To defer messages until interaction, keep a set of touched field names and filter
the displayed errors; keep submission gated on the whole validated result.

Every edit marks the UI busy immediately. The current update Future must settle
before submission becomes available. `pendingFields` can identify individual
field subtrees still running, but an empty set does not guarantee that async
cross-field rules have finished. This example deliberately shows one form-wide
indicator until all validation for the revision settles.

The session prevents stale revisions from publishing data. The widget also
checks an edit counter and the delta revision before updating its busy/error
state. This matters when someone types again while an earlier check is awaiting
a network response. Password changes rerun the confirmation rule without
requiring the user to edit confirmation again.

## Submission and lifecycle

Submission reads `session.validated`, captures the payload, and disables edits
while saving. Confirmation is a UI field and is left out of the request. The demo
does not create an account; replace its delay with your server call and handle
server validation errors as part of that response.

Dispose the session when the widget is removed. If async initialization finishes
after removal, dispose that newly created session too. Check `mounted` after
awaits before changing widget state.

Disposal and new revisions cancel Acanthis's cooperative signal, but do not
forcibly stop a network request. Connect your HTTP client's cancellation support
to the validation scope when available. See [live validation](/live-validation)
for cancellation, revision snapshots, and scheduling, and
[contextual rules](/contextual-rules) for injecting request services.
