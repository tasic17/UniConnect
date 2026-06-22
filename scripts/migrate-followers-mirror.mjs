/**
 * Jednokratna migracija cele baze: za svaki users/{uid}/following/{targetId}
 * kreira users/{targetId}/followers/{uid} ako ne postoji.
 *
 * Zahteva Firebase service account JSON (Admin SDK).
 *
 * Korišćenje:
 *   cd scripts
 *   npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS="../path/to/service-account.json"
 *   npm run migrate:followers
 */

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import admin from "firebase-admin";

const __dirname = dirname(fileURLToPath(import.meta.url));

function initFirebase() {
  const credPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    resolve(__dirname, "service-account.json");

  const serviceAccount = JSON.parse(readFileSync(credPath, "utf8"));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.firestore();
}

async function migrate() {
  const db = initFirebase();
  const followingSnap = await db.collectionGroup("following").get();

  console.log(`Pronađeno ${followingSnap.size} following zapisa.`);

  let created = 0;
  let skipped = 0;
  let errors = 0;

  const userCache = new Map();

  async function userProfile(uid) {
    if (userCache.has(uid)) return userCache.get(uid);
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.exists ? snap.data() : {};
    const profile = {
      displayName: data.displayName || "Korisnik",
      profileImageURL: data.profileImageURL ?? null,
    };
    userCache.set(uid, profile);
    return profile;
  }

  let batch = db.batch();
  let batchOps = 0;
  const batchLimit = 400;

  async function commitBatch() {
    if (batchOps === 0) return;
    await batch.commit();
    batch = db.batch();
    batchOps = 0;
  }

  for (const doc of followingSnap.docs) {
    const followerUserId = doc.ref.parent.parent?.id;
    if (!followerUserId) {
      errors += 1;
      continue;
    }

    const data = doc.data();
    const targetUserId = data.targetUserId || doc.id;
    if (!targetUserId || targetUserId === followerUserId) {
      skipped += 1;
      continue;
    }

    const followerRef = db
      .collection("users")
      .doc(targetUserId)
      .collection("followers")
      .doc(followerUserId);

    const existing = await followerRef.get();
    if (existing.exists) {
      skipped += 1;
      continue;
    }

    const profile = await userProfile(followerUserId);
    const createdAt =
      data.createdAt instanceof admin.firestore.Timestamp
        ? data.createdAt
        : admin.firestore.FieldValue.serverTimestamp();

    batch.set(followerRef, {
      followerUserId,
      displayName: profile.displayName,
      profileImageURL: profile.profileImageURL,
      createdAt,
    });
    batchOps += 1;
    created += 1;

    if (batchOps >= batchLimit) {
      await commitBatch();
      console.log(`… commit (${created} kreirano do sada)`);
    }
  }

  await commitBatch();

  console.log("");
  console.log("Migracija završena.");
  console.log(`  Kreirano: ${created}`);
  console.log(`  Preskočeno (već postoji): ${skipped}`);
  console.log(`  Greške: ${errors}`);
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
