/**
 * RetailSAudit server-only report-mail starter.
 * NOT WIRED TO THE FLUTTER MVP YET. Needs a real Firebase project, storage,
 * role profiles and deployment before it can deliver anything.
 *
 * To use, set GMAIL_APP_PASSWORD as a Firebase Functions secret on YOUR OWN
 * project; never embed email credentials in Flutter source or share in chat.
 * Prefer a managed transactional mail provider for a company production system.
 */
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
admin.initializeApp();

const APP_PASSWORD = defineSecret('GMAIL_APP_PASSWORD');
const REPORT_ADDRESS = 'retailsaudit@gmail.com';
const VALID_KINDS = ['audit', 'soh', 'variance'];

/**
 * On a future cloud-backed app, clients upload generated XLSX files to:
 * report-bundles/{auditId}/{bundleId}/{audit|soh|variance}.xlsx
 * Then invoke this callable with {auditId, bundleId}. This function checks
 * authentication, membership, all three files and filename/path safety.
 */
exports.emailThreeReports = onCall(
  {secrets: [APP_PASSWORD], timeoutSeconds: 120, memory: '512MiB'},
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const {auditId, bundleId} = request.data || {};
    for (const v of [auditId, bundleId]) {
      if (typeof v !== 'string' || !/^[A-Za-z0-9_-]{1,80}$/.test(v)) {
        throw new HttpsError('invalid-argument', 'Invalid audit or bundle ID');
      }
    }
    const actor = await admin.firestore().doc(`users/${request.auth.uid}`).get();
    if (!actor.exists || actor.data().active !== true ||
        !['admin', 'employee'].includes(actor.data().role)) {
      throw new HttpsError('permission-denied', 'Inactive or unauthorized account');
    }
    const audit = await admin.firestore().doc(`audits/${auditId}`).get();
    if (!audit.exists) throw new HttpsError('not-found', 'Audit not found');
    const orgId = actor.data().orgId;
    if (!orgId || audit.data().orgId !== orgId) {
      throw new HttpsError('permission-denied', 'Audit belongs to another organization');
    }
    const storage = admin.storage().bucket();
    const attachments = [];
    for (const kind of VALID_KINDS) {
      const path = `report-bundles/${auditId}/${bundleId}/${kind}.xlsx`;
      const file = storage.file(path);
      const [exists] = await file.exists();
      if (!exists) throw new HttpsError('failed-precondition', `Missing ${kind} report`);
      const [metadata] = await file.getMetadata();
      if (Number(metadata.size || 0) > 10 * 1024 * 1024) {
        throw new HttpsError('resource-exhausted', 'Attachment exceeds 10MB');
      }
      if ((metadata.metadata || {}).orgid !== orgId) {
        throw new HttpsError('permission-denied', 'Invalid report file metadata');
      }
      const [content] = await file.download();
      attachments.push({filename: `${kind.toUpperCase()}_Report.xlsx`, content,
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
    }
    // Avoid repeat sends by acquiring an idempotency lock before SMTP delivery.
    const lock = admin.firestore().doc(`emailDeliveries/${auditId}_${bundleId}`);
    const allowed = await admin.firestore().runTransaction(async (tx) => {
      const prior = await tx.get(lock);
      if (prior.exists) return false;
      tx.create(lock, {auditId, bundleId, senderUid: request.auth.uid,
        status: 'processing', createdAt: admin.firestore.FieldValue.serverTimestamp()});
      return true;
    });
    if (!allowed) throw new HttpsError('already-exists', 'This report bundle was already submitted');
    try {
      const transporter = nodemailer.createTransport({service: 'gmail', auth: {
        user: REPORT_ADDRESS, pass: APP_PASSWORD.value()}});
      const info = await transporter.sendMail({
        from: REPORT_ADDRESS,
        to: REPORT_ADDRESS,
        subject: `RetailSAudit — 3 Reports — ${auditId}`,
        text: 'Attached: Audit Report, SOH Report, and Variance Report.',
        attachments,
      });
      await lock.update({status: 'sent', messageId: info.messageId,
        sentAt: admin.firestore.FieldValue.serverTimestamp()});
      return {status: 'sent'};
    } catch (error) {
      await lock.update({status: 'failed', message: String(error.message || error).slice(0, 300)});
      throw new HttpsError('unavailable', 'Email delivery failed; check delivery status');
    }
  });


// Cloud account administration. Bootstrap the first admin through the Firebase
// console with Auth + users/{uid} {role:'admin', active:true, orgId:'retailsaudit'}.
// Never create an admin account from an unauthenticated mobile request.
function requireId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{3,48}$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Invalid employee ID');
  }
  return value.toUpperCase();
}
async function requireAdmin(auth) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  const profile = await admin.firestore().doc(`users/${auth.uid}`).get();
  if (!profile.exists || profile.data().active !== true || profile.data().role !== 'admin' ||
      !profile.data().orgId) throw new HttpsError('permission-denied', 'Admin required');
  return profile.data();
}
exports.createEmployee = onCall(async (request) => {
  const actor = await requireAdmin(request.auth);
  const id = requireId(request.data?.id);
  const name = String(request.data?.name || '').trim();
  const password = String(request.data?.password || '');
  if (!name || name.length > 120 || password.length < 12) {
    throw new HttpsError('invalid-argument', 'Name and password (12+ characters) required');
  }
  const email = `${id.toLowerCase()}@staff.retailsaudit.invalid`;
  let user;
  try {
    user = await admin.auth().createUser({email, password, displayName: name, disabled: false});
    await admin.firestore().doc(`users/${user.uid}`).create({
      id, name, email, orgId: actor.orgId, role: 'employee', active: true,
      createdBy: request.auth.uid, createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    if (user) await admin.auth().deleteUser(user.uid);
    if (err.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'Employee ID already exists');
    }
    throw new HttpsError('internal', 'Employee creation failed');
  }
  return {uid: user.uid, id};
});
exports.suspendEmployee = onCall(async (request) => {
  const actor = await requireAdmin(request.auth);
  const uid = String(request.data?.uid || '');
  if (!/^[A-Za-z0-9_-]{10,128}$/.test(uid) || uid === request.auth.uid) {
    throw new HttpsError('invalid-argument', 'Invalid employee');
  }
  const ref = admin.firestore().doc(`users/${uid}`);
  const doc = await ref.get();
  if (!doc.exists || doc.data().orgId !== actor.orgId || doc.data().role !== 'employee') {
    throw new HttpsError('permission-denied', 'Not an employee in your organization');
  }
  await admin.auth().updateUser(uid, {disabled: true});
  await admin.auth().revokeRefreshTokens(uid);
  await ref.update({active: false, suspendedAt: admin.firestore.FieldValue.serverTimestamp()});
  return {suspended: true};
});
