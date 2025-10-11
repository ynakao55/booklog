# Rails Booklog — 読書ログ（Ruby on Rails + PostgreSQL）

本のタイトル・著者・読書ステータスを管理するシンプルな CRUD アプリ。  
Ruby on Rails（Rails 8 系） + PostgreSQL。Render.com にデプロイできます。

> ✅ アプリURL / GitHub リポジトリはあなたのものに差し替えてください  
> - App: `https://...` ←（あとで差し替え）  
> - GitHub: `https://github.com/...` ←（あとで差し替え）

---

## 機能
- 本の登録 / 一覧 / 詳細 / 削除（CRUD）
- **ステータス管理**：`unread` / `reading` / `done`（`enum`）
- **フィルタ**：先頭の「All / Unread / Reading / Done」で一覧を絞り込み
- **バリデーション**：`title` / `author` / `status` 必須
- **Note の短縮表示**：一覧は先頭10文字＋省略記号（詳細画面で全文）
- **ベースレイアウト**（`base.html.erb` 相当）：ヘッダに「[New book] + Filter」、下に一覧テーブル

---

## 画面
- `/books` … 一覧（先頭に「[New book] Filter: All | Unread | Reading | Done」）
- `/books/new` … 新規作成フォーム
- `/books/:id` … 詳細表示
- （任意）`/` を `/books` にリダイレクト

> フィルタはクエリ（例：`/books?status=unread`）またはタブリンクで切替。

---

## ローカル実行

### 1) 依存インストール
```bash
bundle install
```

### 2) DB 設定（PostgreSQL）
`config/database.yml` の例（ローカル）：
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  host: localhost
  port: 5432
  username: postgres
  password: password

development:
  <<: *default
  database: booklog_dev

test:
  <<: *default
  database: booklog_test

production:
  <<: *default
  database: booklog_prod
```

> Docker 例：
```bash
docker run -d --name booklog-db   -e POSTGRES_PASSWORD=password -e POSTGRES_DB=booklog_dev   -p 5432:5432 postgres:16
```

### 3) DB 作成＆マイグレーション
```bash
bin/rails db:create db:migrate
```

### 4) 起動
```bash
bin/rails server
# http://localhost:3000
```

---

## 主要モデル / バリデーション（抜粋）

```ruby
# app/models/book.rb
class Book < ApplicationRecord
  enum status: { unread: 0, reading: 1, done: 2 }
  validates :title, :author, :status, presence: true
end
```

> 一覧の Note は `note.truncate(10)` でトリム表示（詳細で全文）。

---

## Render へのデプロイ手順

### 0) 前提
- GitHub に push 済み
- Render で PostgreSQL（Free可）を作成

### 1) Web Service を作成
- “Create Web Service” → リポジトリを選択

### 2) **Environment Variables** を設定
- `RAILS_ENV=production`
- `RACK_ENV=production`
- `DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/DBNAME?sslmode=require` ← **必須（sslmode=require）**
- **どちらか一方**
  - `RAILS_MASTER_KEY=<config/master.key の中身>`（Credentials を使う場合）
  - `SECRET_KEY_BASE=<bin/rails secret で作成>`（Credentials を使わない場合）
- （推奨）`RAILS_LOG_TO_STDOUT=true`
- （静的配信ありなら）`RAILS_SERVE_STATIC_FILES=true`

### 3) **Start Command**
無料プランでも安全に起動できるよう、起動前に自動で migrate します。
```
bundle exec rails db:migrate && bundle exec puma -C config/puma.rb
```

> `config/puma.rb` が無い場合の代替：
> ```
> bundle exec rails db:migrate && bundle exec puma -t 5:5 -p ${PORT:-3000} -e production
> ```

### 4) （Rails 8 系）Solid 系の追加設定
Rails 8 は **Solid Queue（ジョブ）** と **Solid Cache（キャッシュ）** を利用できます。  
DB 一台構成なら **同じ DB をロールで共有**させるのが手軽です。

`config/database.yml`（production の例）：
```yaml
production:
  primary: &primary
    url: <%= ENV["DATABASE_URL"] %> # ← Render の URL（?sslmode=require 付き）
    pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>

  queue:
    <<: *primary

  cable:
    <<: *primary

  cache:
    <<: *primary
```

**マイグレーション作成（初回のみ）**：
```bash
bin/rails g solid_queue:install
bin/rails g solid_cache:install
bin/rails db:migrate
git add .
git commit -m "Add Solid Queue/Cache"
git push
```

> 代替（暫定運用）  
> - ジョブを使わない → `config.active_job.queue_adapter = :async`（`production.rb`）  
> - キャッシュを DB に置かない → `config.cache_store = :memory_store` などへ切替

---

## 動作チェック（Render）
1. Deploy log にエラーがないこと（`Migrations are pending` / `database ... not configured` が出ない）  
2. 画面 `/books` が表示され、  
   - 先頭に「[New book] Filter: All | Unread | Reading | Done」  
   - テーブルに `Title / Author / Status / Note / Show`  
   - Note が10文字にトリム  
   を確認

---

## よくあるハマりどころ（Tips）
- **`DATABASE_URL` の末尾に `?sslmode=require`** を付け忘れると接続に失敗します。
- Rails 8 では **`queue` / `cache` / `cable` の DB ロール**が未定義だと起動時に落ちます（上記の `database.yml` 例を流用するのが最短）。
- 無料プランは **Pre-Deploy Command が使えない**ため、**Start Command で `db:migrate` を連結**します。
- Credentials を使うなら **`RAILS_MASTER_KEY`** を Render の Environment に必ず設定。

---

## 開発メモ
- 一覧テーブルはヘッダとリストを **レイアウトで視覚的に分離**（ヘッダに `[New book] Filter ...`、下段にテーブル）。
- フィルタ UI はステータスタブのリンク（`/books?status=reading` など）で実装。
- ルーティングは `resources :books` を基本に最小構成。

---

## ライセンス
MIT License
