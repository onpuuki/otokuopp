const admin = require('firebase-admin');

// Initialize the app with a service account, granting admin privileges
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function getConfig() {
  const doc = await db.collection('settings').doc('config').get();
  if (doc.exists) {
    console.log(JSON.stringify(doc.data(), null, 2));
  } else {
    console.log('No such document!');
  }
}

getConfig();
