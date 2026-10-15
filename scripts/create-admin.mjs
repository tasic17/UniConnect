/**
 * Creates an administrator account: a Firebase Auth user with a verified email
 * plus a Firestore users/{uid} document with role: "admin".
 *
 * Credentials are read from the environment — never hardcode them.
 *
 * Usage (service account):
 *   cd scripts
 *   npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS="../path/to/service-account.json"
 *   export ADMIN_EMAIL="you@example.com"
 *   export ADMIN_PASSWORD="<a strong password>"
 *   npm run create:admin
 *
 * Usage (local emulator):
 *   export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
 *   export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
 *   export GCLOUD_PROJECT="your-project-id"
 *   export ADMIN_EMAIL="..." ADMIN_PASSWORD="..."
 *   npm run create:admin
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import admin from "firebase-admin";

const __dirname = dirname(fileURLToPath(import.meta.url));

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
const ADMIN_NAME = process.env.ADMIN_NAME || "Admin";

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error(
    "Set ADMIN_EMAIL and ADMIN_PASSWORD before running this script, e.g.\n" +
      '  export ADMIN_EMAIL="you@example.com"\n' +
      '  export ADMIN_PASSWORD="<a strong password>"'
  );
  process.exit(1);
}

if (ADMIN_PASSWORD.length < 8) {
  console.error("ADMIN_PASSWORD must be at least 8 characters long.");
  process.exit(1);
}

function initFirebase() {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const usingEmulator =
    process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST;

  if (usingEmulator) {
    const projectId =
      process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      "demo-uniconnect";
    admin.initializeApp({ projectId });
    console.log(`Emulator mode (project: ${projectId})`);
    return admin.firestore();
  }

  if (!credPath || !existsSync(credPath)) {
    console.error(
      "Set GOOGLE_APPLICATION_CREDENTIALS to your service-account.json,\n" +
        "or run against the emulators via FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST."
    );
    process.exit(1);
  }

  const serviceAccount = JSON.parse(readFileSync(credPath, "utf8"));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.firestore();
}

async function ensureAdminUser() {
  const auth = admin.auth();
  let user;

  try {
    user = await auth.createUser({
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      displayName: ADMIN_NAME,
      emailVerified: true,
    });
    console.log(`Created Auth user: ${user.uid}`);
  } catch (err) {
    if (err.code !== "auth/email-already-exists") throw err;
    user = await auth.getUserByEmail(ADMIN_EMAIL);
    await auth.updateUser(user.uid, {
      password: ADMIN_PASSWORD,
      displayName: ADMIN_NAME,
      emailVerified: true,
    });
    console.log(`Updated existing Auth user: ${user.uid}`);
  }

  return user;
}

async function main() {
  const db = initFirebase();
  const user = await ensureAdminUser();

  await db
    .collection("users")
    .doc(user.uid)
    .set(
      {
        uid: user.uid,
        displayName: ADMIN_NAME,
        email: ADMIN_EMAIL,
        year: 1,
        department: "Softversko inzenjerstvo",
        bio: "Platform administrator",
        profileImageURL: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        role: "admin",
        banned: false,
        bannedUntil: null,
      },
      { merge: true }
    );

  console.log("\nAdmin account ready:");
  console.log(`  Email:     ${ADMIN_EMAIL}`);
  console.log(`  UID:       ${user.uid}`);
  console.log(`  Firestore: users/${user.uid} (role: admin)`);
  console.log("\nSign in with these credentials — the Admin tab appears once the email is verified (already verified in Auth).");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
