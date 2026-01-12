const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const CLOUDINARY_API_SECRET = functions.config().cloudinary.api_secret;
const CLOUDINARY_API_KEY = functions.config().cloudinary.api_key;
const CLOUDINARY_CLOUD_NAME = "javid";

exports.generateCloudinarySignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { businessId } = data;

  if (businessId) {
    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    if (!businessDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Business not found');
    }
    const businessData = businessDoc.data();
    if (businessData.ownerId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Not owner');
    }
  }

  const timestamp = Math.round((new Date()).getTime() / 1000);
  const folderPath = `businesses/${businessId}`;
  
  const params = {
    timestamp: timestamp,
    folder: folderPath,
  };

  const paramsString = Object.keys(params).sort().map(key => `${key}=${params[key]}`).join('&');
  const signature = crypto.createHash('sha256').update(paramsString + CLOUDINARY_API_SECRET).digest('hex');

  return {
    signature: signature,
    timestamp: timestamp,
    apiKey: CLOUDINARY_API_KEY,
    cloudName: CLOUDINARY_CLOUD_NAME,
    folder: folderPath,
  };
});

exports.generateCloudinaryDeleteSignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
  }

  const userId = context.auth.uid;
  const { publicId, businessId } = data;

  if (businessId) {
    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    if (!businessDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Business not found');
    }
    const businessData = businessDoc.data();
    if (businessData.ownerId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Not owner');
    }
  }

  const timestamp = Math.round((new Date()).getTime() / 1000);
  const params = { public_id: publicId, timestamp: timestamp };
  const paramsString = Object.keys(params).sort().map(key => `${key}=${params[key]}`).join('&');
  const signature = crypto.createHash('sha256').update(paramsString + CLOUDINARY_API_SECRET).digest('hex');

  return {
    signature: signature,
    timestamp: timestamp,
    apiKey: CLOUDINARY_API_KEY,
    publicId: publicId,
  };
});
