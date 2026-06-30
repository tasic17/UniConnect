/**
 * Kreira admin nalog: admin@gmail.com / admin123
 * + Firestore users/{uid} sa role: "admin" i emailVerified u Auth.
 *
 * Korišćenje (produkcija / service account):
 *   cd scripts
 *   npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS="../path/to/service-account.json"
 *   npm run create:admin
 *
 * Emulator:
 *   export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
 *   export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
 *   export GCLOUD_PROJECT="your-project-id"
 *   npm run create:admin
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import admin from "firebase-admin";

const __dirname = dirname(fileURLToPath(import.meta.url));

const ADMIN_EMAIL = "admin@gmail.com";
const ADMIN_PASSWORD = "admin123";
const ADMIN_NAME = "Admin";

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
    console.log(`Emulator mod (project: ${projectId})`);
    return admin.firestore();
  }

  if (!credPath || !existsSync(credPath)) {
    console.error(
      "Postavi GOOGLE_APPLICATION_CREDENTIALS na service-account.json\n" +
        "ili pokreni sa FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST."
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
    console.log(`Kreiran Auth korisnik: ${user.uid}`);
  } catch (err) {
    if (err.code !== "auth/email-already-exists") throw err;
    user = await auth.getUserByEmail(ADMIN_EMAIL);
    await auth.updateUser(user.uid, {
      password: ADMIN_PASSWORD,
      displayName: ADMIN_NAME,
      emailVerified: true,
    });
    console.log(`Ažuriran postojeći Auth korisnik: ${user.uid}`);
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

  console.log("\nAdmin nalog spreman:");
  console.log(`  Email:    ${ADMIN_EMAIL}`);
  console.log(`  Lozinka:  ${ADMIN_PASSWORD}`);
  console.log(`  UID:      ${user.uid}`);
  console.log(`  Firestore: users/${user.uid} (role: admin)`);
  console.log("\nUloguj se u aplikaciju — tab Admin će se pojaviti nakon verifikacije emaila (već verified u Auth).");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
