const functions = require('@google-cloud/functions-framework');
const cheerio = require('cheerio');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const admin = require('firebase-admin');
const ngeohash = require('ngeohash');

// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 1. Webページの取得: 任意のURLからHTMLを取得し、cheerio等の軽量ライブラリを用いてプレーンテキストを抽出する関数。
 */
async function fetchAndExtractText(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch URL: ${response.statusText}`);
    }
    const html = await response.text();
    const $ = cheerio.load(html);

    // Remove scripts, styles to clean up
    $('script, style, noscript').remove();

    // Extract text
    const text = $('body').text().replace(/\s+/g, ' ').trim();
    return text;
  } catch (error) {
    console.error('Error fetching and extracting text:', error);
    throw error;
  }
}

/**
 * 2. Gemini API連携: 抽出したテキストをGemini API（gemini-2.5-flash）に渡し、
 * Phase 1で作成した `mock-data.json` のスキーマに完全に一致するJSON構造化データとして出力させる関数。
 */
async function extractCampaignData(text, apiKey) {
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is missing.');
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const prompt = `
You are a helpful assistant that extracts campaign and sale information from unstructured text and structures it into JSON.
Please extract any campaigns, sales, or deals from the following text.
Output MUST be valid JSON only. Do not wrap it in markdown block like \`\`\`json.
The output MUST strictly follow this JSON schema for the 'campaigns' array:

{
  "campaigns": [
    {
      "id": "A unique string ID for the campaign (you can generate one if not present, e.g., 'campaign-001')",
      "title": "The title of the campaign or sale",
      "storeName": "The name of the store",
      "location": {
        "latitude": 35.6369, // Approximate latitude if not available, try to guess from store name or set to a default number.
        "longitude": 139.4463 // Approximate longitude
      },
      // Do NOT include geohash here, it will be added later
      "details": "Details about the campaign, discount, etc.",
      "expiresAt": "Expiration date in ISO 8601 format (e.g., '2024-12-31T23:59:59Z'). Try to guess from text, if not set to a future date."
    }
  ]
}

Text to extract from:
${text}
`;

  try {
    const result = await model.generateContent(prompt);
    const responseText = result.response.text();

    // Clean up potential markdown wrapping
    let jsonString = responseText.trim();
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.replace(/^```json/, '').replace(/```$/, '').trim();
    } else if (jsonString.startsWith('```')) {
        jsonString = jsonString.replace(/^```/, '').replace(/```$/, '').trim();
    }

    const data = JSON.parse(jsonString);
    return data.campaigns || [];
  } catch (error) {
    console.error('Error extracting campaign data from Gemini:', error);
    throw error;
  }
}

/**
 * 3. Firestore保存: GeminiからのJSONデータに対し、緯度経度からngeohashを利用してGeohashを生成して付与し、
 * Firestoreの `campaigns` コレクションに保存する関数。
 */
async function saveCampaignsToFirestore(campaigns) {
  const db = admin.firestore();
  const batch = db.batch();

  for (const campaign of campaigns) {
    // Generate Geohash
    if (campaign.location && campaign.location.latitude && campaign.location.longitude) {
      campaign.geohash = ngeohash.encode(campaign.location.latitude, campaign.location.longitude);
    } else {
        // Fallback geohash if no location, though location should be provided
        campaign.geohash = '';
    }

    // Save to Firestore
    const docRef = db.collection('campaigns').doc(campaign.id);
    batch.set(docRef, campaign);
  }

  try {
    await batch.commit();
    console.log(`Successfully saved ${campaigns.length} campaigns to Firestore.`);
  } catch (error) {
    console.error('Error saving campaigns to Firestore:', error);
    throw error;
  }
}

/**
 * Cloud Function Entry Point
 */
functions.http('scrapeCampaign', async (req, res) => {
  const db = admin.firestore();
  let urls = [];

  try {
    const configDoc = await db.collection('settings').doc('config').get();
    if (configDoc.exists) {
      urls = configDoc.data().targetUrls || [];
    }
  } catch (error) {
    console.error('Error fetching targetUrls from Firestore:', error);
    return res.status(500).send({ error: 'Failed to fetch configuration' });
  }

  if (!urls || urls.length === 0) {
    return res.status(200).send({ message: 'No target URLs configured.', count: 0 });
  }

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    let totalCampaigns = 0;
    let allCampaigns = [];

    for (const url of urls) {
      console.log(`Scraping URL: ${url}`);
      try {
        const text = await fetchAndExtractText(url);
        const campaigns = await extractCampaignData(text, apiKey);

        if (campaigns && campaigns.length > 0) {
          await saveCampaignsToFirestore(campaigns);
          totalCampaigns += campaigns.length;
          allCampaigns.push(...campaigns);
        }
      } catch (err) {
        console.error(`Error processing url ${url}:`, err);
        // Continue to the next URL even if one fails
      }
    }

    if (totalCampaigns > 0) {
      res.status(200).send({ message: 'Successfully scraped and saved campaigns', count: totalCampaigns, campaigns: allCampaigns });
    } else {
      res.status(200).send({ message: 'No campaigns found in the provided URLs.', count: 0 });
    }

  } catch (error) {
    console.error('Fatal error in scrapeCampaign:', error);
    res.status(500).send({ error: error.message });
  }
});

// Export functions for testing
module.exports = {
  fetchAndExtractText,
  extractCampaignData,
  saveCampaignsToFirestore
};
