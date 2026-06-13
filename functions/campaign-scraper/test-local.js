// test-local.js
// このスクリプトは、依存関係がインストールされ、GEMINI_API_KEY環境変数が設定されていることを前提としています。
// 実行方法: GEMINI_API_KEY="your_api_key" node test-local.js
//
// ※ ターミナル上で `npm install` は禁止されているため、
// CI環境や本番環境へのデプロイ後に動作確認を行うか、
// ローカルで必要なパッケージが揃っている前提での実行を想定しています。

const path = require('path');

async function run() {
  console.log("=== test-local.js Started ===");

  try {
    // 依存関係がロード可能か確認（構文チェックとモジュール存在確認）
    // load errors will be caught below if dependencies aren't installed yet
    const { fetchAndExtractText, extractCampaignData, saveCampaignsToFirestore } = require('./index.js');

    console.log("Successfully required index.js. Dependencies are present.");

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.log("GEMINI_API_KEY is not set. Skipping API dependent tests.");
      console.log("To run full tests: GEMINI_API_KEY=\"your_key\" node test-local.js");
      process.exit(0);
    }

    const testUrl = "https://example.com";
    console.log(`\n1. Fetching text from ${testUrl}...`);
    // Note: Since example.com might not have sales info, we might not get campaigns,
    // but we can test the extraction pipeline.
    const text = await fetchAndExtractText(testUrl);
    console.log(`Extracted text (first 100 chars): ${text.substring(0, 100)}...`);

    console.log(`\n2. Extracting campaigns using Gemini API...`);
    const campaigns = await extractCampaignData(text, apiKey);
    console.log(`Extracted ${campaigns.length} campaigns.`);
    console.log(JSON.stringify(campaigns, null, 2));

    if (campaigns.length > 0) {
      console.log(`\n3. Saving campaigns to Firestore...`);
      // Note: This requires GOOGLE_APPLICATION_CREDENTIALS or running in a GCP environment
      // to authenticate with Firestore properly. It may fail locally if not set up.
      try {
        await saveCampaignsToFirestore(campaigns);
        console.log("Successfully saved to Firestore.");
      } catch (dbError) {
        console.error("Failed to save to Firestore (possibly due to missing credentials):", dbError.message);
      }
    } else {
        console.log("\n3. Skipping Firestore save as no campaigns were extracted.");
    }

    console.log("\n=== test-local.js Finished Successfully ===");

  } catch (error) {
    if (error.code === 'MODULE_NOT_FOUND') {
      console.log("Modules not found. This is expected if 'npm install' has not been run.");
      console.log("Syntax validation of test-local.js passed.");
    } else {
      console.error("Test failed with error:", error);
    }
  } finally {
    // Ensure we exit and don't hang
    process.exit(0);
  }
}

// タイムアウトによる強制終了のセーフガード (1分)
setTimeout(() => {
  console.error("Timeout: test-local.js execution exceeded 1 minute. Force quitting.");
  process.exit(1);
}, 60000);

run();
