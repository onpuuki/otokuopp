# システム構成（アーキテクチャ）

本プロジェクトは、「次世代型ハイブリッド・リワードハブアプリ」のシステム構成を示します。
GCPの無料枠と10ドル/月のクレジット内に収めるため、完全なサーバーレス構成を採用しています。

## 全体構成図 (Mermaid)

```mermaid
graph TD
    %% ユーザーインターフェース
    subgraph Frontend [Frontend (Flutter)]
        App[Flutter App]
        WebView[WebView Component<br/>ワンクリック応募などの手動消化]
        App --> WebView
    end

    %% バックエンド＆データベース
    subgraph Backend [Backend (Firebase / GCP)]
        Firestore[(Firestore)]
        Geohash[Geohash Index<br/>位置情報検索]
        Firestore --- Geohash
    end

    %% データ収集・処理パイプライン
    subgraph DataPipeline [Data Collection & Processing (GCP Serverless)]
        Scraper[Cloud Run / Cloud Functions<br/>キャンペーン・セール情報のスクレイピング]
        Gemini[Gemini API<br/>JSON構造化]
        Scraper -->|生データ| Gemini
        Gemini -->|構造化データ| Firestore
    end

    %% 課金停止用キルスイッチ
    subgraph KillSwitch [Cost Control (Kill Switch)]
        BillingAlert[Pub/Sub<br/>予算アラート通知]
        CloudFunction[Cloud Run Functions<br/>課金強制解除]
        BillingAPI[GCP Billing API]
        BillingAlert --> CloudFunction
        CloudFunction -->|billingAccountName = ''| BillingAPI
    end

    %% 相互接続
    App -->|位置情報検索・データ取得| Firestore
    WebView -->|ユーザーアクション送信| Firestore
```

## アーキテクチャの要点

1.  **Frontend (Flutter)**:
    *   クロスプラットフォームのモバイルアプリ。
    *   ネイティブのUIとWebViewを組み合わせたハイブリッド構成。
    *   キャンペーン応募などの複雑な画面遷移やWebフォーム操作は、WebViewを経由して処理。

2.  **Backend (Firebase / GCP)**:
    *   **Firestore**: NoSQLデータベースとして利用。
    *   **Geohash**: 店舗情報やキャンペーン情報の位置データ（緯度・経度）をGeohashアルゴリズムを用いてインデックス化し、ユーザーの現在地に基づいた高速な周辺検索を実現。

3.  **Data Collection & Processing**:
    *   **スクレイピング**: 定期的にGCPのサーバーレス環境（Cloud Run jobs or Cloud Functions等）でWeb上のキャンペーン情報やセール情報を収集。
    *   **Gemini API**: 収集した非構造化データをGemini APIを用いて解析し、アプリで利用しやすいJSON形式に構造化してFirestoreに保存。

4.  **Cost Control (Kill Switch)**:
    *   設定したGCP予算上限（100%）に到達した際、Pub/Sub経由で通知を受け取る。
    *   Cloud Run Functionsがトリガーされ、`projects.updateBillingInfo` APIを呼び出してプロジェクトの課金を強制的に停止し、意図しないコスト超過を防止。
