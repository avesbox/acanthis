import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const envelope = JSON.parse(readFileSync(process.argv[2], 'utf8'));
assert.equal(envelope.version, 1);
const pointer = path => path.map(part => '/' + String(part).replaceAll('~', '~0').replaceAll('/', '~1')).join('');
const issue = envelope.issues[0];
assert.equal(issue.code, 'minLength');
assert.deepEqual(issue.parameters, {value: 3});
assert.equal(pointer(issue.path), '/email');
assert.equal('message' in issue, false);
const messages = {
  en: p => `Value must contain at least ${p.value} characters`,
  it: p => `Il valore deve contenere almeno ${p.value} caratteri`,
};
assert.equal(messages.en(issue.parameters), 'Value must contain at least 3 characters');
assert.equal(messages.it(issue.parameters), 'Il valore deve contenere almeno 3 caratteri');
console.log('PASS: JavaScript consumes versioned codes, constraints and paths');
