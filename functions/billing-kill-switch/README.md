# Billing Kill Switch

このディレクトリには、GCPの予算アラート（Pub/Sub通知）を受け取り、プロジェクトの課金を強制的に停止するCloud Run Functions（Node.js）のコードが含まれています。

## デプロイ手順

1.  **GCP プロジェクトの設定**: 対象のGCPプロジェクトが選択されていることを確認します。
    ```bash
    gcloud config set project YOUR_PROJECT_ID
    ```

2.  **Pub/Sub トピックの作成**: 予算アラートを通知するPub/Subトピック（例：`billing-alerts`）を作成します。
    ```bash
    gcloud pubsub topics create billing-alerts
    ```

3.  **予算とアラートの設定**: GCPコンソールの「お支払い（Billing）」>「予算とアラート」から、10ドルクレジット内に収まる予算を作成し、アクションとして作成したPub/Subトピック（`billing-alerts`）への通知を設定します。

4.  **関数のデプロイ**: `functions/billing-kill-switch` ディレクトリで以下のコマンドを実行し、関数をデプロイします。
    ```bash
    gcloud functions deploy stopBilling \
      --runtime nodejs20 \
      --trigger-topic billing-alerts \
      --region asia-northeast1 \
      --entry-point stopBilling \
      --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
    ```
    ※ `YOUR_PROJECT_ID` は実際のプロジェクトIDに置き換えてください。

## 必要なIAM権限

この関数を実行するサービスアカウント（通常はApp Engineのデフォルトサービスアカウント、またはCloud Functions用に作成したカスタムサービスアカウント）には、以下のIAMロールが必要です。

*   **プロジェクト課金管理者 (`roles/billing.projectManager`)**: プロジェクトの課金情報（`billingAccountName`）を更新するために必要です。
*   **課金アカウント管理者 (`roles/billing.admin`)**: (※要件によっては不要な場合もありますが、プロジェクトを課金アカウントからリンク解除するためには、対象となる請求先アカウントに対する管理者権限が必要となるケースがあります。)

**注意**: この設定により、予算上限を超えると即座にプロジェクトの課金が停止され、リソースが停止・削除される可能性があります。意図した動作であることを十分に確認してください。
