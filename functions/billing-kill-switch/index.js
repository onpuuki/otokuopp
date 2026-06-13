const { CloudBillingClient } = require('@google-cloud/billing');

/**
 * 予算アラートのPub/Subメッセージを受け取り、指定されたプロジェクトの課金を停止する
 *
 * @param {Object} message Pub/Subメッセージオブジェクト
 * @param {Object} context コンテキストオブジェクト
 */
exports.stopBilling = async (message, context) => {
  const pubsubData = JSON.parse(Buffer.from(message.data, 'base64').toString());
  console.log(`Received budget alert: ${JSON.stringify(pubsubData)}`);

  // コスト超過（100%以上の予算消化）の場合のみ処理を実行
  if (pubsubData.costAmount <= pubsubData.budgetAmount) {
    console.log(`Cost amount ${pubsubData.costAmount} is less than or equal to budget amount ${pubsubData.budgetAmount}. No action taken.`);
    return;
  }

  // プロジェクトIDの取得 (環境変数か、Pub/Subのペイロードに含まれる想定)
  const projectId = process.env.GOOGLE_CLOUD_PROJECT || 'YOUR_PROJECT_ID'; // 環境変数から取得するのがベストプラクティス
  const projectName = `projects/${projectId}`;

  console.log(`Threshold exceeded. Disabling billing for project: ${projectName}`);

  const billingClient = new CloudBillingClient();

  try {
    // 課金アカウント情報を空文字にして課金を強制解除する
    const request = {
      name: projectName,
      projectBillingInfo: {
        billingAccountName: '', // 空文字にすることで課金停止
      },
    };

    const [response] = await billingClient.updateProjectBillingInfo(request);
    console.log(`Billing disabled successfully for project ${projectId}. Response:`, response);
  } catch (error) {
    console.error(`Failed to disable billing for project ${projectId}:`, error);
    throw error;
  }
};
