# dependency-track-sample

Dependency-Track（v5.2.2）を自分の機械で起動し、わざと古い版を並べた業務アプリ風のコンテナ 4 つ（shop-web・shop-api・admin・blog。AlmaLinux 8.4）の SBOM を預けて、脆弱性の番号 `CVE-2020-17541` から「どのアプリに入っているか」を引くまでの最小サンプルです。
動画: dependency-track の回 no01（公開後に URL を追記）。

## 使い方

入れておく物は Docker（Compose v2 付き）・git・curl だけです。

```bash
git clone <このリポの URL> dependency-track-sample
cd dependency-track-sample

# 1. 起動（初回はイメージの取得があります）
docker compose up -d
#    画面は http://127.0.0.1:8081 ・API は http://127.0.0.1:8080
#    ログインは admin / admin。最初のログインでパスワードの変更を求められます

# 2. admin のパスワードを決め、API キーを作る（キーは標準出力に出るだけで、ファイルには書きません）
export DT_ADMIN_PASSWORD='自分で決めたパスワード'
export DT_API_KEY="$(./scripts/setup.sh)"

# 3. 脆弱性の公開データ（NVD）の取り込みが終わるまで待つ（手元の機械と回線で約 3 分）
./scripts/wait-ready.sh

# 4. sbom/ の 4 本を上げる（プロジェクトは自動で作られ、取り込みの完了まで待ちます）
./scripts/upload.sh

# 5. CVE-2020-17541 が入っているプロジェクトを引く
./scripts/affected.sh
# shop-web 1.0
# shop-api 1.0
# admin 1.0        ← blog は出ません（この脆弱性の部品が入っていないため）
```

- 2 の `setup.sh` は、画面の Administration > Access Management > Teams > Automation で API キーを作る手と同じ結果にします（Automation チームに `PROJECT_CREATION_UPLOAD`・`VIEW_VULNERABILITY`・`SYSTEM_CONFIGURATION_READ` を足してキーを 1 本作る）。画面で作ったキーを使うなら、そのチームに同じ 3 つを足してください
- 画面で見るなら、左の Vulnerabilities の検索欄に `CVE-2020-17541` → 行を開く → タブ Affected Projects
- 別のコピーと同時に動かすなどでポートを変えるときは、`DT_API_PORT=28080 DT_UI_PORT=28081 docker compose up -d` のように起動し、スクリプト側にも `export DT_API_PORT=28080` を渡します
- 別の番号も引けます: `./scripts/affected.sh CVE-番号`（NVD に載っている番号）
- 片付け: `docker compose down -v`（このサンプルのコンテナとボリュームだけ消えます）

## 中身

| 物 | 内容 |
|---|---|
| `compose.yaml` | 公式の quickstart の compose をもとに、apiserver・frontend を `5.2.2` に固定し、ポートを 127.0.0.1 だけに開く（PostgreSQL は `postgres:18-alpine`） |
| `sbom/*.cdx.json` | Syft 1.57.2 の `-o cyclonedx-json`（CycloneDX 1.7）で作った SBOM 4 本。AlmaLinux 8.4 のコンテナに nginx 1.14.1・PHP 7.2.24・Tomcat 9.0.40・Rails 6.0.3.2 を入れたイメージから作成。プロジェクト名は業務アプリ風の別名で、`shop-web`＝nginx、`shop-api`＝PHP、`admin`＝Tomcat、`blog`＝Rails のイメージ |
| `scripts/setup.sh` | admin の初回パスワード変更 → API キー作成 |
| `scripts/wait-ready.sh` | NVD の取り込み完了待ち |
| `scripts/upload.sh` | SBOM を上げて、取り込み完了まで待つ |
| `scripts/affected.sh` | 番号から影響プロジェクトを引く |

秘密はリポに置きません。パスワードと API キーは環境変数で渡します（`.env.example` は項目の一覧だけです）。

## 実測の時点（2026-11-20〜21・aarch64・メモリ 8GB・1 回）

| 物 | 値 |
|---|---|
| Dependency-Track | v5.2.2（2026-11-18 リリース） |
| 起動 | compose の up から、画面 6 秒・API 10 秒で応答 |
| 初回の取り込み | NVD 約 2 分 40 秒（439,365 件）。取り込みの間の合計メモリはいちばん多いときで約 2.1GB |
| 脆弱性の公開データ | NVD は既定で有効。OSV・GitHub Advisories・JVN は既定で無効（このサンプルは変えていません） |

NVD は日々動くので、後から回すと件数や当たる脆弱性は変わることがあります。待ち時間は回線次第です。

## これで全部が見えるわけではありません

- 0 件でも「入っていない」とは限りません。公開データに無い物・照らし直しの前・CPE の無い部品は出ません
- 出た 3 本は、箱の中の部品 `libjpeg-turbo 1.5.3-10.el8` に当たったものです（nginx など、アプリの本体の脆弱性ではありません）。Linux の配布元は版番号を変えずに修正を取り込むことがあり、NVD の照合は直した版にも当たることがあります。本当に直っているかは配布元の勧告で確かめてください
- SBOM は上げた時点の部品の一覧です。部品を変えたら上げ直してください
- SBOM の作者欄のメールアドレスは除いた（部品と版は Syft の出力のまま）
- Dependency-Track v4 は 2026 年 12 月に保守終了予定（公式 README）です。このサンプルは v5.2.2 だけを扱います

## ライセンス

MIT（`LICENSE`）。Dependency-Track は Apache License 2.0 です。
