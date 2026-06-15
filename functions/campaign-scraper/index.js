const functions = require('@google-cloud/functions-framework');
const cheerio = require('cheerio');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const admin = require('firebase-admin');
const ngeohash = require('ngeohash');
const { PubSub } = require('@google-cloud/pubsub');

// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
  admin.initializeApp();
}

const pubSubClient = new PubSub();

/**
 * 1. Webページの取得: 任意のURLからHTMLを取得し、cheerio等の軽量ライブラリを用いてプレーンテキストを抽出する関数。
 */
async function fetchAndExtractText(url, logs = []) {
  try {
    logs.push(`[fetchAndExtractText] Fetching URL: ${url}`);
    const response = await fetch(url, { signal: AbortSignal.timeout(10000) });
    logs.push(`[fetchAndExtractText] Response status: ${response.status}`);
    if (!response.ok) {
      throw new Error(`Failed to fetch URL: ${response.statusText}`);
    }
    const html = await response.text();
    const $ = cheerio.load(html);

    // Remove scripts, styles to clean up
    $('script, style, noscript').remove();

    // Extract text
    const text = $('body').text().replace(/\s+/g, ' ').trim();
    console.log(`[fetchAndExtractText] Extracted ${text.length} characters from ${url}`);
    logs.push(`[fetchAndExtractText] Extracted ${text.length} characters from ${url}`);
    return text;
  } catch (error) {
    console.error('Error fetching and extracting text:', error);
    logs.push(`[fetchAndExtractText] Error: ${error.message}`);
    throw error;
  }
}

/**
 * 2. Gemini API連携: 抽出したテキストをGemini API（gemini-2.5-flash）に渡し、
 * Phase 1で作成した `mock-data.json` のスキーマに完全に一致するJSON構造化データとして出力させる関数。
 */
async function extractCampaignData(text, apiKey, logs = []) {
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
      "details": "対象のキャンペーンの種類を判別し、'details' フィールドは以下のルールに従って必ず箇条書き（・）の改行テキストとして出力すること。情報がサイトにない項目は『記載なし』とすること。\\n- ポイント獲得サイトの場合：・貯まるポイント名、・ポイント数 を箇条書き。\\n- 抽選サイトの場合：・当たるもの、・抽選条件、・抽選期間、・当選確率、・当選発表日、・応募条件 を箇条書き。\\n- 上記以外のキャンペーン情報の場合：・対象のサイトや店舗名、・キャンペーンの概要 を箇条書き。",
      "expiresAt": "Expiration date in ISO 8601 format (e.g., '2024-12-31T23:59:59Z'). Try to guess from text, if not set to a future date."
    }
  ]
}

Text to extract from:
${text}
`;

  try {
    console.log(`[extractCampaignData] Calling Gemini API...`);
    logs.push(`[extractCampaignData] Calling Gemini API...`);
    const result = await model.generateContent(prompt);
    console.log(`[extractCampaignData] Gemini API call completed.`);
    logs.push(`[extractCampaignData] Gemini API call completed.`);
    const responseText = result.response.text();
    console.log(`[extractCampaignData] Raw Gemini response:`, responseText);

    // Clean up potential markdown wrapping
    let jsonString = responseText.trim();
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.replace(/^```json/, '').replace(/```$/, '').trim();
    } else if (jsonString.startsWith('```')) {
        jsonString = jsonString.replace(/^```/, '').replace(/```$/, '').trim();
    }

    const data = JSON.parse(jsonString);
    logs.push(`[extractCampaignData] Successfully parsed JSON. Extracted ${(data.campaigns || []).length} campaigns.`);
    return data.campaigns || [];
  } catch (error) {
    console.error('Error extracting campaign data from Gemini:', error);
    logs.push(`[extractCampaignData] Error: ${error.message}`);
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
 * Cloud Function Entry Point - HTTP Trigger to start scraping job
 */
functions.http('startScraping', async (req, res) => {
  let executionLogs = [];
  try {
    const isManual = req.body && req.body.isManual === true;
    if (!isManual) {
      const configDoc = await admin.firestore().collection('settings').doc('config').get();
      if (configDoc.exists) {
        const isAutoScrapingEnabled = configDoc.data().isAutoScrapingEnabled;
        if (isAutoScrapingEnabled === false) {
          console.log("Auto-scraping is disabled.");
          executionLogs.push("Auto-scraping is disabled.");
          return res.status(200).send({ message: 'Auto-scraping is disabled.', count: 0, executionLogs });
        }
      }
    }
  } catch (error) {
    console.error("Error reading auto-scraping config:", error);
    executionLogs.push(`Error reading auto-scraping config: ${error.message}`);
  }

  let urls = req.body.urls;

  if (!urls && req.query.url) {
    urls = [req.query.url];
  } else if (!urls && req.body.url) {
    urls = [req.body.url];
  }

  if (!urls || !Array.isArray(urls) || urls.length === 0) {
    try {
      console.log("No URLs provided in request, attempting to fetch targetUrls from Firestore settings/config...");
      const configDoc = await admin.firestore().collection('settings').doc('config').get();
      if (configDoc.exists) {
        const targetUrls = configDoc.data().targetUrls;
        if (Array.isArray(targetUrls) && targetUrls.length > 0) {
          urls = targetUrls;
          console.log("Successfully fetched targetUrls from Firestore.");
        }
      }
    } catch (error) {
      console.error("Error reading targetUrls from config:", error);
    }

    if (!urls || urls.length === 0) {
      console.log("Falling back to default dummy URLs.");
      urls = [
        'https://example.com/campaigns',
        'https://example.com/sales'
      ];
    }
  }

  try {
    const db = admin.firestore();

    // Clear old campaigns before starting a new job
    const campaignsSnapshot = await db.collection('campaigns').get();
    if (!campaignsSnapshot.empty) {
      const batch = db.batch();
      campaignsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
    }
    executionLogs.push(`Deleted ${campaignsSnapshot.size} old campaigns.`);
    console.log(`Deleted ${campaignsSnapshot.size} old campaigns.`);

    const jobRef = await db.collection('scraping_jobs').add({
      totalUrls: urls.length,
      completedUrls: 0,
      status: 'running',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const jobId = jobRef.id;
    const topic = pubSubClient.topic('scrape-url-topic');

    for (const url of urls) {
      const messageBuffer = Buffer.from(JSON.stringify({ url, jobId }));
      await topic.publishMessage({ data: messageBuffer });
    }

    res.status(200).send({
      message: 'Scraping job started successfully',
      jobId: jobId,
      totalUrls: urls.length,
      executionLogs
    });

  } catch (error) {
    console.error('Fatal error in startScraping:', error);
    executionLogs.push(`Fatal error in startScraping: ${error.message}`);
    res.status(500).send({ error: error.message, executionLogs });
  }
});

/**
 * Cloud Function Entry Point - Pub/Sub Trigger to process individual URL
 */
functions.cloudEvent('processUrlTask', async (cloudEvent) => {
  const base64name = cloudEvent.data.message.data;
  const messageStr = Buffer.from(base64name, 'base64').toString('utf-8');
  const messageData = JSON.parse(messageStr);

  const { url, jobId } = messageData;
  const apiKey = process.env.GEMINI_API_KEY;
  let executionLogs = [];

  console.log(`[processUrlTask] Processing URL: ${url} for Job ID: ${jobId}`);

  try {
    const text = await fetchAndExtractText(url, executionLogs);
    const campaigns = await extractCampaignData(text, apiKey, executionLogs);

    if (campaigns && campaigns.length > 0) {
      campaigns.forEach(c => c.url = url);
      await saveCampaignsToFirestore(campaigns);
    }
  } catch (error) {
    console.error(`[processUrlTask] Error processing url ${url}:`, error);
  } finally {
    // Always increment the completedUrls count whether success or failure, and check completion
    if (jobId) {
      try {
        const db = admin.firestore();
        const jobRef = db.collection('scraping_jobs').doc(jobId);

        await db.runTransaction(async (transaction) => {
          const doc = await transaction.get(jobRef);
          if (!doc.exists) {
            throw new Error('Job document does not exist!');
          }

          const currentCompleted = doc.data().completedUrls || 0;
          const totalUrls = doc.data().totalUrls || 0;
          const newCompleted = currentCompleted + 1;

          if (newCompleted >= totalUrls) {
            transaction.update(jobRef, {
              completedUrls: newCompleted,
              status: 'completed'
            });
            console.log(`[processUrlTask] Job ID: ${jobId} status updated to completed. (${newCompleted}/${totalUrls})`);
          } else {
            transaction.update(jobRef, {
              completedUrls: newCompleted
            });
            console.log(`[processUrlTask] Incremented completedUrls for Job ID: ${jobId}. (${newCompleted}/${totalUrls})`);
          }
        });
      } catch (dbError) {
        console.error(`[processUrlTask] Failed to update job progress for Job ID: ${jobId}:`, dbError);
      }
    }
  }
});

// Export functions for testing
module.exports = {
  fetchAndExtractText,
  extractCampaignData,
  saveCampaignsToFirestore
};
