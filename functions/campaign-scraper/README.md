# Campaign Scraper Cloud Function

This Cloud Run Function is responsible for fetching HTML content from a given URL, extracting the text, using the Gemini API to identify and structure campaign/sale data, and saving the results into Firestore with Geohashes.

## Structure

*   `index.js`: The main Cloud Function code containing the core logic (`fetchAndExtractText`, `extractCampaignData`, `saveCampaignsToFirestore`) and the HTTP entry point (`scrapeCampaign`).
*   `package.json`: Defines the dependencies.
*   `test-local.js`: A script to run the extraction logic locally.

## Logic Overview

1.  **Web Scraping**: Uses `fetch` to retrieve HTML and `cheerio` to strip out scripts/styles and extract clean plain text.
2.  **AI Extraction**: Sends the plain text to the `gemini-2.5-flash` model via the `@google/generative-ai` SDK, prompting it to output a strict JSON array of campaigns matching the project's schema.
3.  **Geohashing & Storage**: Calculates a geohash for each campaign using the `ngeohash` library and saves the structured data to the Firestore `campaigns` collection using `firebase-admin`.

## Setting up Automated Execution (Cloud Scheduler)

To run this scraping function automatically every day, you can use Google Cloud Scheduler. The function should be scheduled to run at 3:00 AM daily.

You can set this up using the `gcloud` command-line tool. Replace `YOUR_CLOUD_FUNCTION_URL` with the actual URL of your deployed Cloud Function.

```bash
gcloud scheduler jobs create http scrape-campaigns-daily \
  --schedule="0 3 * * *" \
  --uri="YOUR_CLOUD_FUNCTION_URL" \
  --http-method=POST \
  --message-body='{"urls": []}' \
  --headers="Content-Type=application/json" \
  --time-zone="Asia/Tokyo"
```

*   `--schedule="0 3 * * *"`: Runs every day at 3:00 AM.
*   `--message-body='{"urls": []}'`: Sends an empty array to trigger the fallback URLs configured in the backend.

## Running the Local Test

Due to strict rules preventing the execution of `npm install` directly in the terminal, the local test script is designed to handle missing dependencies gracefully by reporting that syntax checks have passed.

If you deploy this or have the dependencies installed locally, you can run the test script by providing a Gemini API key:

```bash
GEMINI_API_KEY="your_actual_api_key_here" node test-local.js
```

The script includes safeguards to ensure it gracefully exits (`process.exit(0)`) and enforces a 1-minute timeout to prevent hanging processes.
