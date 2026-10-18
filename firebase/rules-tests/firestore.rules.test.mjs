// Firestore security-rule tests. Run from the repo root:
//   cd firebase/rules-tests && npm install        (once)
//   cd ../.. && firebase emulators:exec --only firestore --project demo-securecampus "npm --prefix firebase/rules-tests test"
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, serverTimestamp, writeBatch } from 'firebase/firestore';

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

// ---------------------------------------------------------------- campus + stop locations
test('the campus needs a name and real coordinates; Attock saves, nonsense does not', async () => {
  const admin = as('admin1');
  await assertSucceeds(setDoc(doc(admin, 'config/transport'),
    { campusName: 'COMSATS University Islamabad, Attock Campus', campusLat: 33.78099, campusLng: 72.35105 }, { merge: true }));
  await assertFails(setDoc(doc(admin, 'config/transport'), { campusName: '', campusLat: 33.78, campusLng: 72.35 }));
  await assertFails(setDoc(doc(admin, 'config/transport'), { campusName: 'X', campusLat: 133.78, campusLng: 72.35 }));
  await assertFails(setDoc(doc(admin, 'config/transport'), { campusName: 'X', campusLat: 33.78, campusLng: 272.35 }));
  await assertFails(setDoc(doc(admin, 'config/transport'), { campusName: 'X', campusLat: '33.78', campusLng: 72.35 }));
});

test('only the admin adds, moves or removes a bus stop, with real coordinates', async () => {
  const stop = { name: 'Stop A', lat: 33.77, lng: 72.36, order: 1 };
  await assertSucceeds(setDoc(doc(as('admin1'), 'busStops/S1'), stop));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'busStops/S1'), { order: 2 })); // reordering the route
  await assertSucceeds(getDoc(doc(as('stu1'), 'busStops/S1')));
  await assertFails(setDoc(doc(as('stu1'), 'busStops/S2'), stop));
  await assertFails(setDoc(doc(as('admin1'), 'busStops/S3'), { ...stop, lat: 200 }));
  await assertFails(setDoc(doc(as('admin1'), 'busStops/S4'), { ...stop, name: '' }));
  await assertFails(setDoc(doc(as('admin1'), 'busStops/S5'), { name: 'No coords', order: 1 }));
  await assertFails(deleteDoc(doc(as('stu1'), 'busStops/S1')));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'busStops/S1')));
});

// ---------------------------------------------------------------- found-card reports
const foundReport = (over = {}) => ({
  studentName: 'Ayesha Khan', registrationNumber: 'FA23-BSE-001', location: 'Library',
  description: '', notified: false, status: 'OPEN', createdAt: serverTimestamp(),
  finderUid: 'finder1', hasPhoto: false, ...over,
});

test('anyone signed in can file an OPEN report with a name and number; nothing else', async () => {
  const finder = env.authenticatedContext('finder1').firestore(); // anonymous-style session, no users doc
  await assertSucceeds(addDoc(collection(finder, 'lostCardReports'), foundReport()));
  await assertFails(addDoc(collection(finder, 'lostCardReports'), foundReport({ studentName: '' })));
  await assertFails(addDoc(collection(finder, 'lostCardReports'), foundReport({ registrationNumber: '' })));
  await assertFails(addDoc(collection(finder, 'lostCardReports'), foundReport({ status: 'RESOLVED' })));
  await assertFails(addDoc(collection(finder, 'lostCardReports'), foundReport({ notified: true })));
  await assertFails(addDoc(collection(env.unauthenticatedContext().firestore(), 'lostCardReports'), foundReport()));
});

test('Admin and Security read reports; only Admin resolves or deletes; students and finders cannot read', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'lostCardReports/r1'), foundReport({ createdAt: new Date() }));
  });
  await assertSucceeds(getDoc(doc(as('admin1'), 'lostCardReports/r1')));
  await assertSucceeds(getDoc(doc(as('sec1'), 'lostCardReports/r1')));
  await assertFails(getDoc(doc(as('stu1'), 'lostCardReports/r1')));
  await assertFails(getDoc(doc(as('lib1'), 'lostCardReports/r1')));

  await assertFails(updateDoc(doc(as('sec1'), 'lostCardReports/r1'), { status: 'RESOLVED' }));
  await assertFails(deleteDoc(doc(as('sec1'), 'lostCardReports/r1')));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'lostCardReports/r1'), { status: 'RESOLVED', resolvedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'lostCardReports/r1')));
});

// ---------------------------------------------------------------- Phase 2 collections are closed
test('attendance, gate entries, iris profiles and security alerts are not open to any role in Phase 1', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'attendance/a1'), { studentId: 'stu1' });
    await setDoc(doc(db, 'gateEntries/g1'), { studentId: 'stu1' });
    await setDoc(doc(db, 'irisProfiles/stu1'), { code: 'x' });
    await setDoc(doc(db, 'securityAlerts/s1'), { status: 'NEW' });
  });
  for (const path of ['attendance/a1', 'gateEntries/g1', 'irisProfiles/stu1', 'securityAlerts/s1']) {
    for (const uid of ['admin1', 'sec1', 'stu1', 'lib1']) {
      await assertFails(getDoc(doc(as(uid), path)));
    }
  }
});

test('Security cannot read student records in Phase 1; the student and librarian still can', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'students/stu1'), { name: 'A', registrationNumber: 'FA23-BSE-001' });
  });
  await assertFails(getDoc(doc(as('sec1'), 'students/stu1')));
  await assertSucceeds(getDoc(doc(as('stu1'), 'students/stu1')));
  await assertSucceeds(getDoc(doc(as('lib1'), 'students/stu1')));
});

// ---------------------------------------------------------------- found-card photo
const photoDoc = (over = {}) => ({ data: 'aGVsbG8=', createdAt: serverTimestamp(), ...over });

test('a report must name its finder; the photo flag must be a boolean', async () => {
  const finder = env.authenticatedContext('finder1').firestore();
  await assertFails(addDoc(collection(finder, 'lostCardReports'), foundReport({ finderUid: 'someone-else' })));
  const { finderUid, ...withoutFinder } = foundReport(); // no finderUid field at all
  await assertFails(addDoc(collection(finder, 'lostCardReports'), withoutFinder));
  await assertFails(addDoc(collection(finder, 'lostCardReports'), foundReport({ hasPhoto: 'yes' })));
});

test('the finder can attach a small photo, in the same write as their own report', async () => {
  const finder = env.authenticatedContext('finder1').firestore();
  const reportRef = doc(collection(finder, 'lostCardReports'));
  const batch = writeBatch(finder);
  batch.set(reportRef, foundReport({ hasPhoto: true }));
  batch.set(doc(finder, 'lostCardPhotos', reportRef.id), photoDoc());
  await assertSucceeds(batch.commit());
});

test('a photo is refused if the report does not say it has one, is someone else\'s, is too big or has extra fields', async () => {
  const finder = env.authenticatedContext('finder1').firestore();

  // report says hasPhoto: false
  let ref = doc(collection(finder, 'lostCardReports'));
  let batch = writeBatch(finder);
  batch.set(ref, foundReport({ hasPhoto: false }));
  batch.set(doc(finder, 'lostCardPhotos', ref.id), photoDoc());
  await assertFails(batch.commit());

  // too big (over 800,000 characters)
  ref = doc(collection(finder, 'lostCardReports'));
  batch = writeBatch(finder);
  batch.set(ref, foundReport({ hasPhoto: true }));
  batch.set(doc(finder, 'lostCardPhotos', ref.id), photoDoc({ data: 'A'.repeat(800001) }));
  await assertFails(batch.commit());

  // extra field
  ref = doc(collection(finder, 'lostCardReports'));
  batch = writeBatch(finder);
  batch.set(ref, foundReport({ hasPhoto: true }));
  batch.set(doc(finder, 'lostCardPhotos', ref.id), { ...photoDoc(), note: 'x' });
  await assertFails(batch.commit());

  // a photo for a report that belongs to someone else
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'lostCardReports/other'), foundReport({ finderUid: 'finder2', hasPhoto: true, createdAt: new Date() }));
  });
  await assertFails(setDoc(doc(finder, 'lostCardPhotos/other'), photoDoc()));
  // and a photo with no report at all
  await assertFails(setDoc(doc(finder, 'lostCardPhotos/nothing'), photoDoc()));
});

test('only the Admin reads or deletes a card photo; nobody can change one', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'lostCardReports/r9'), foundReport({ hasPhoto: true, createdAt: new Date() }));
    await setDoc(doc(db, 'lostCardPhotos/r9'), { data: 'aGVsbG8=', createdAt: new Date() });
  });
  await assertSucceeds(getDoc(doc(as('admin1'), 'lostCardPhotos/r9')));
  await assertFails(getDoc(doc(as('sec1'), 'lostCardPhotos/r9')));   // Security can read the report but never the photo
  await assertFails(getDoc(doc(as('stu1'), 'lostCardPhotos/r9')));
  await assertFails(getDoc(doc(env.authenticatedContext('finder1').firestore(), 'lostCardPhotos/r9')));
  await assertFails(updateDoc(doc(as('admin1'), 'lostCardPhotos/r9'), { data: 'x' }));
  await assertFails(deleteDoc(doc(as('sec1'), 'lostCardPhotos/r9')));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'lostCardPhotos/r9')));
});

// ---------------------------------------------------------------- courses
test('only the Admin adds, renames or deletes a course, and it needs a real name; everyone signed in can read', async () => {
  await assertSucceeds(setDoc(doc(as('admin1'), 'courses/SE'), { name: 'Software Engineering' }));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'courses/SE'), { name: 'Software Engineering II' }));
  await assertSucceeds(getDoc(doc(as('stu1'), 'courses/SE')));
  await assertFails(setDoc(doc(as('admin1'), 'courses/XX'), { name: '' }));
  await assertFails(setDoc(doc(as('admin1'), 'courses/XX'), { name: 'A' }));
  await assertFails(setDoc(doc(as('admin1'), 'courses/XX'), { title: 'no name field' }));
  await assertFails(setDoc(doc(as('stu1'), 'courses/YY'), { name: 'Not allowed' }));
  await assertFails(setDoc(doc(as('lib1'), 'courses/YY'), { name: 'Not allowed' }));
  await assertFails(deleteDoc(doc(as('stu1'), 'courses/SE')));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'courses/SE')));
});
