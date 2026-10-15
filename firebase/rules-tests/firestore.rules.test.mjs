// Firestore security-rule tests. Run from the repo root:
//   cd firebase/rules-tests && npm install        (once)
//   cd ../.. && firebase emulators:exec --only firestore --project demo-securecampus "npm --prefix firebase/rules-tests test"
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(here, '..', 'firestore.rules'), 'utf8');

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-securecampus',
    firestore: { rules, host, port: Number(port) },
  });
});

after(async () => env?.cleanup());

// Fresh data before every test: role documents the rules read, plus books and loans.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (uid, role) => setDoc(doc(db, 'users', uid), { uid, role, active: true });
    await user('admin1', 'admin');
    await user('lib1', 'librarian');
    await user('sec1', 'security');
    await user('stu1', 'student');
    await user('stu2', 'student');

    await setDoc(doc(db, 'books', 'B1'), { title: 'Algorithms', available: true, locked: false });
    await setDoc(doc(db, 'books', 'B2'), { title: 'Networks', available: true, locked: true, lockReason: 'in safe' });
    await setDoc(doc(db, 'libraryIssues', 'issue-stu1'), { studentId: 'stu1', bookId: 'B3', returned: false });
    await setDoc(doc(db, 'libraryIssues', 'issue-stu2'), { studentId: 'stu2', bookId: 'B4', returned: false });
    await setDoc(doc(db, 'gateEntries', 'g1'), { studentId: 'stu1' });
    await setDoc(doc(db, 'irisProfiles', 'stu1'), { code: 'x' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const lockEvent = (uid, over = {}) => ({
  action: 'LOCK', reason: 'damaged cover', byUid: uid, byName: 'Name', byRole: 'librarian', at: serverTimestamp(), ...over,
});

// ---------------------------------------------------------------- lock history
test('librarian and admin can append a lock event with their own uid', async () => {
  await assertSucceeds(addDoc(collection(as('lib1'), 'books/B1/lockHistory'), lockEvent('lib1')));
  await assertSucceeds(addDoc(collection(as('admin1'), 'books/B2/lockHistory'),
    lockEvent('admin1', { action: 'UNLOCK', byRole: 'admin', reason: 'back in circulation' })));
});

test('a lock event cannot name someone else, have no reason, or carry extra fields', async () => {
  const lib = as('lib1');
  await assertFails(addDoc(collection(lib, 'books/B1/lockHistory'), lockEvent('admin1')));
  await assertFails(addDoc(collection(lib, 'books/B1/lockHistory'), lockEvent('lib1', { reason: '' })));
  await assertFails(addDoc(collection(lib, 'books/B1/lockHistory'), lockEvent('lib1', { reason: 'x'.repeat(201) })));
  await assertFails(addDoc(collection(lib, 'books/B1/lockHistory'), lockEvent('lib1', { action: 'DELETE' })));
  await assertFails(addDoc(collection(lib, 'books/B1/lockHistory'), lockEvent('lib1', { extra: true })));
});

test('lock history is append-only and not readable by students or security', async () => {
  const ref = await addDoc(collection(as('lib1'), 'books/B1/lockHistory'), lockEvent('lib1'));
  await assertFails(updateDoc(doc(as('lib1'), ref.path), { reason: 'edited' }));
  await assertFails(deleteDoc(doc(as('admin1'), ref.path)));
  await assertSucceeds(getDoc(doc(as('lib1'), ref.path)));
  await assertSucceeds(getDoc(doc(as('admin1'), ref.path)));
  await assertFails(getDoc(doc(as('stu1'), ref.path)));
  await assertFails(getDoc(doc(as('sec1'), ref.path)));
});

// ---------------------------------------------------------------- locked books
test('a locked book cannot be issued, an unlocked one can', async () => {
  const issue = (bookId) => ({ bookId, studentId: 'stu1', returned: false });
  await assertSucceeds(addDoc(collection(as('lib1'), 'libraryIssues'), issue('B1')));
  await assertFails(addDoc(collection(as('lib1'), 'libraryIssues'), issue('B2')));
  await assertFails(addDoc(collection(as('admin1'), 'libraryIssues'), issue('B2')));
});

test('students cannot issue books or change books', async () => {
  await assertFails(addDoc(collection(as('stu1'), 'libraryIssues'), { bookId: 'B1', studentId: 'stu1', returned: false }));
  await assertFails(updateDoc(doc(as('stu1'), 'books/B1'), { locked: true }));
});

test('librarian can still return a loan', async () => {
  await assertSucceeds(updateDoc(doc(as('lib1'), 'libraryIssues/issue-stu1'), { returned: true, returnMethod: 'scan' }));
});

// ---------------------------------------------------------------- student data isolation
test('a student reads only their own loans', async () => {
  await assertSucceeds(getDoc(doc(as('stu1'), 'libraryIssues/issue-stu1')));
  await assertFails(getDoc(doc(as('stu1'), 'libraryIssues/issue-stu2')));
});

test('students cannot read gate entries or iris profiles; security can read gate entries', async () => {
  await assertFails(getDoc(doc(as('stu1'), 'gateEntries/g1')));
  await assertFails(getDoc(doc(as('stu1'), 'irisProfiles/stu1')));
  await assertFails(getDoc(doc(as('admin1'), 'irisProfiles/stu1'))); // nobody reads biometrics from a client
  await assertSucceeds(getDoc(doc(as('sec1'), 'gateEntries/g1')));
});

// ---------------------------------------------------------------- student reports
const report = (uid, issueId, over = {}) => ({
  issueId, bookId: 'B3', bookTitle: 'T', studentId: uid, studentName: 'N', registrationNumber: 'R',
  note: 'not mine', status: 'NEW', createdAt: serverTimestamp(), ...over,
});

test('a student can report only a loan that is theirs', async () => {
  await assertSucceeds(addDoc(collection(as('stu1'), 'issueReports'), report('stu1', 'issue-stu1')));
  await assertFails(addDoc(collection(as('stu1'), 'issueReports'), report('stu1', 'issue-stu2'))); // someone else's loan
  await assertFails(addDoc(collection(as('stu1'), 'issueReports'), report('stu2', 'issue-stu1'))); // posing as another student
});

test('a report must have the expected shape', async () => {
  const s = as('stu1');
  await assertFails(addDoc(collection(s, 'issueReports'), report('stu1', 'issue-stu1', { status: 'RESOLVED' })));
  await assertFails(addDoc(collection(s, 'issueReports'), report('stu1', 'issue-stu1', { note: 'x'.repeat(201) })));
  await assertFails(addDoc(collection(s, 'issueReports'), report('stu1', 'issue-stu1', { extra: 1 })));
});

test('staff read reports and change only the status; students cannot edit or read others', async () => {
  const ref = await addDoc(collection(as('stu1'), 'issueReports'), report('stu1', 'issue-stu1'));
  await assertSucceeds(getDoc(doc(as('lib1'), ref.path)));
  await assertSucceeds(getDoc(doc(as('sec1'), ref.path)));
  await assertSucceeds(getDoc(doc(as('stu1'), ref.path)));
  await assertFails(getDoc(doc(as('stu2'), ref.path)));

  await assertSucceeds(updateDoc(doc(as('lib1'), ref.path), { status: 'RESOLVED' }));
  await assertFails(updateDoc(doc(as('lib1'), ref.path), { note: 'rewritten' }));
  await assertFails(updateDoc(doc(as('stu1'), ref.path), { status: 'RESOLVED' }));
});

// ---------------------------------------------------------------- first-login password flag
test('a user can clear their own must-change-password flag, only to false', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', 'stu1'), { uid: 'stu1', role: 'student', active: true, mustResetPassword: true });
  });
  await assertSucceeds(updateDoc(doc(as('stu1'), 'users/stu1'), { mustResetPassword: false }));
  await assertFails(updateDoc(doc(as('stu1'), 'users/stu1'), { mustResetPassword: true }));
});

test('a user cannot use that rule to change their role, active flag, or anyone else', async () => {
  await assertFails(updateDoc(doc(as('stu1'), 'users/stu1'), { role: 'admin' }));
  await assertFails(updateDoc(doc(as('stu1'), 'users/stu1'), { active: false }));
  await assertFails(updateDoc(doc(as('stu1'), 'users/stu1'), { mustResetPassword: false, role: 'admin' }));
  await assertFails(updateDoc(doc(as('stu1'), 'users/stu2'), { mustResetPassword: false }));
});

test('fcmToken updates still work for the user and admin can still edit users', async () => {
  await assertSucceeds(updateDoc(doc(as('stu1'), 'users/stu1'), { fcmToken: 'abc' }));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'users/stu1'), { active: false }));
});

// ---------------------------------------------------------------- transport config
test('everyone signed in reads the campus location; only the admin writes it', async () => {
  const campus = { campusName: 'CUI Attock', campusLat: 33.77, campusLng: 72.36 };
  await assertSucceeds(setDoc(doc(as('admin1'), 'config/transport'), campus));
  await assertSucceeds(getDoc(doc(as('stu1'), 'config/transport')));
  await assertFails(setDoc(doc(as('stu1'), 'config/transport'), campus));
  await assertFails(setDoc(doc(as('lib1'), 'config/transport'), campus));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'config/transport')));
});
