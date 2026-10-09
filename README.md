# TypeSpec × openapi_first × Rails

TypeSpec に書いた API 契約を Rails のリクエスト検証と RSpec のレスポンス検証に使う、小さなタスク管理アプリです。
仕様を書く、OpenAPI を生成する、Rails を実装する、仕様とのずれをテストで検出する、という流れを体験できます。
Rails の通常のモデル、コントローラー、request spec と、ビルド不要の操作画面で構成しています。

## 仕様から実装までの役割

API が受け付ける入力と返す出力を、**API 契約**として TypeSpec に定義します。
DB のテーブルやアプリの処理は、それぞれ Rails の migration と Ruby のコードに書きます。
TypeSpec から OpenAPI を生成し、その OpenAPI からブラウザーで読める API ドキュメントの HTML を生成します。

| 要素 | 役割 |
| --- | --- |
| TypeSpec | API 契約の正本。共通の型、文字数、状態の候補、必須項目、HTTP の操作を定義する |
| OpenAPI 3.1 | TypeSpec から生成する YAML。openapi_first が読む共通の契約 |
| Redocly CLI | OpenAPI から API の操作、入力、レスポンスを読める HTML を生成する |
| openapi_first | API の入口でリクエストを検証し、テストでは HTTP ステータス、Content-Type、レスポンス本文も検証する |
| Rails | ルーティング、保存、検索、部分更新、JSON の返却、静的画面の配信を行う |
| RSpec | 実際の Rails アプリへリクエストを送り、契約と保存結果を確認する |

`api/main.tsp` → `npm run openapi` → `openapi/openapi.yaml` → openapi_first、という順に契約が渡ります。
同じコマンドが `public/api-docs.html` も生成し、検証に使う契約をブラウザーでも確認できます。
TypeSpec の `TaskTitle` は作成、更新、レスポンスで使い、`TaskStatus` は更新、一覧の絞り込み、レスポンスで再利用します。

## 必要な環境とセットアップ

採用したバージョンは次のとおりです。
Ruby と Node.js は、利用中のバージョン管理ツールでこのリポジトリに必要な版を選択してください。
Ruby の gem や npm パッケージを使うためのインターネット接続と、必要に応じて OS のビルドツールも必要です。

| ツール | バージョン |
| --- | --- |
| Ruby | 4.0.6（`.ruby-version`） |
| Bundler | 4.0.16（`Gemfile.lock`） |
| Rails | 8.1.3.1 |
| Node.js | 24.18.0（`.node-version`） |
| npm | 11.16.0 |
| TypeSpec の公式パッケージ 4 個 | すべて 1.17.0 |
| Redocly CLI | 2.61.0 |
| openapi_first | 4.2.0 |
| rspec-rails | 8.0.4 |
| Puma | 7.2.1 |
| sqlite3 gem | 2.9.6 |
| json gem（互換性のための制約） | 2.21.2 |

リポジトリのルートで実行します。
Bundler 4.0.16 が選択中の Ruby に入っていなければ、先に `gem install bundler --version 4.0.16` を実行してください。

```sh
ruby -v
node -v
npm -v
bundle _4.0.16_ --version
bin/setup
bin/check
```

`bin/setup` は、プロジェクト内の `vendor/bundle` へ frozen モードで `bundle install` し、`npm ci`、OpenAPI の同期確認、API ドキュメントの生成、`bin/rails db:prepare` を順に実行します。
`Gemfile.lock` と `package-lock.json` の内容から依存を再現し、既存 DB を初期化し直さずに準備します。
サーバー起動は次のコマンドで行います。

```sh
bin/rails server
```

[http://localhost:3000](http://localhost:3000) をブラウザーで開き、タイトルを入力してタスクを作成します。
一覧の状態を変更すると PATCH が送信され、絞り込みを変更すると GET の `status` クエリが変わります。
画面には直近のリクエスト、HTTP ステータス、JSON も表示されます。
HTML、CSS、JavaScript を Rails の `public/` から同一オリジンで配信するため、別のフロントエンドサーバーや CORS の設定は必要ありません。

操作画面の「OpenAPIの仕様を読む」リンク、または [http://localhost:3000/api-docs.html](http://localhost:3000/api-docs.html) から API の操作とスキーマを確認できます。
仕様は生成した HTML に埋め込み、表示用の Redoc はバージョン付き URL と SRI を指定して CDN から読み込みます。
そのため、API ドキュメントをブラウザーで表示する際にはインターネット接続が必要です。
Google Fonts の読み込みは無効にしています。

## API と検証コマンド

初版のタスクは `id`、`title`、`status` の 3 項目を返します。
DB のタイムスタンプはレスポンスに含めません。

| 操作 | 入力 | 成功時のレスポンス |
| --- | --- | --- |
| `POST /api/tasks` | JSON の `title` が必須 | 201 とタスク。`status` は `todo` で保存 |
| `GET /api/tasks` | 任意の `status` クエリ（todo、doing、done） | 200 とタスクの配列。id の昇順 |
| `GET /api/tasks/{id}` | タスクの整数 id | 200 と指定したタスク |
| `PATCH /api/tasks/{id}` | JSON の `title` と `status` が任意 | 200 と更新後のタスク。送った項目だけ更新 |

`title` は 1〜100 文字の文字列、`status` は `todo`、`doing`、`done` のいずれかです。
タイトルの空文字や `null` は拒否しますが、長さを満たす空白文字列はそのまま保存します。
`PATCH` の `{}` は変更しない正常な更新であり、`null` を指定する更新は不正です。
`seal-object-schemas: true` により、リクエスト本文に未定義の項目を追加することも拒否します。
Redoc の表示を正確にするため、各オブジェクトモデルに `@extension("unevaluatedProperties", false)` を付け、既定の `{ not: {} }` と同じ禁止制約を `false` で出力します。
作成時に `status` を指定する操作は初版の契約に含めていません。

入力が契約に合わなければ 400、JSON 以外の Content-Type で本文を送れば 415 です。
この 2 種類のエラーは openapi_first が `application/problem+json` で返し、本文には `title`、`status` と任意の `errors` を含めます。
存在しないタスクは Rails が 404 と `{"error":"Task not found"}` を返します。
これらのエラーレスポンスも TypeSpec の契約に含めています。

```sh
# TypeSpec を変更した後、OpenAPI と API ドキュメントを生成する
npm run openapi

# 保存済み OpenAPI から API ドキュメントだけを生成する
npm run openapi:docs

# 保存済みファイルを書き換えず、TypeSpec と一致するか調べる
npm run openapi:check

# 契約、API の動作、モデルをテストする
bundle exec rspec

# 同期確認、API ドキュメントの生成、RSpec をまとめて実行する
bin/check
```

同期確認は、一時ディレクトリへ再生成した YAML と保存済み YAML をバイト単位で直接比較します。
未コミット、未追跡のファイルでも機能し、チェックによって保存済み生成物の差分を消すことはありません。
TypeSpec の変更後は `npm run openapi` の差分を確認し、Rails とテストを更新してから `bin/check` を実行します。
起動中のサーバーは契約を起動時に読み込むため、OpenAPI を再生成したら再起動してください。

`npm run openapi:docs` は、次の Redocly CLI コマンドを実行します。

```sh
redocly build-docs openapi/openapi.yaml \
  --output public/api-docs.html \
  --disableGoogleFont \
  --theme.openapi.hideDownloadButton=true \
  --title "Tasks API"
```

`redocly` はプロジェクトの npm scripts 内で使うローカルコマンドです。
直接実行する場合は、先頭を `node_modules/.bin/redocly` に置き換えてください。
ダウンロードボタンの生成 HTML とブラウザーの描画が一致しない [上流の既知の問題](https://github.com/Redocly/redoc/issues/2693) に対応し、標準オプションでボタンを非表示にしています。
生成した `public/api-docs.html` は `.gitignore` により Git の追跡対象から除外し、`bin/setup` で再現します。
表示内容を変更するときは TypeSpec と OpenAPI を更新して再生成してください。

## 主要ファイルの読み方

次の順に読むと、契約が検証と実装にどう使われるかを追えます。

| ファイル | 読むポイント |
| --- | --- |
| `api/main.tsp` | `TaskTitle`、`TaskStatus`、入力モデル、出力モデル、HTTP の操作とエラー |
| `tspconfig.yaml` | OpenAPI 3.1 の生成先と、未定義項目を拒否する設定 |
| `openapi/openapi.yaml` | 生成後の required、minLength、maxLength、enum、HTTP ステータス |
| `config/initializers/openapi_first.rb` | 契約の登録と、`/api` 以下のリクエスト検証 |
| `app/models/task.rb` | DB に保存する値のモデル検証 |
| `db/migrate/20261009000000_create_tasks.rb` | NOT NULL、空でない title と状態の CHECK 制約 |
| `app/controllers/api/tasks_controller.rb` | JSON 本文とクエリの入力を分け、`todo` で作成、絞り込み、部分更新、3 項目を返却 |
| `spec/support/openapi_contract.rb` | 通常リクエスト、意図した不正リクエスト、レスポンスの契約検証 |
| `spec/requests/tasks_spec.rb` | 正常入力と不正入力、DB の保存結果、404、部分更新 |
| `spec/models/task_spec.rb` | モデル検証と、モデルを経由しない書き込みへの DB 制約 |
| `public/index.html`、`public/app.css`、`public/app.js` | ビルドなしで動く 1 ページの操作画面 |
| `public/api-docs.html` | OpenAPI から生成するブラウザー用 API ドキュメント。Git の追跡対象外 |
| `bin/setup`、`bin/check`、`bin/check-openapi` | lockfile に基づく準備、検証、生成物の同期確認 |
| `.github/workflows/check.yml` | `bin/check` で同期確認、API ドキュメントの生成、RSpec を実行する最小の CI |

生成された YAML は確認用にも保存しています。
仕様を直すときは `api/main.tsp` を編集して再生成してください。

## RSpec における契約検証

`spec/rails_helper.rb` が契約検証のサポートファイルを読み、`OpenapiFirst::Test.observe(Rails.application)` が request spec の通信を観測します。
通常のテストで送るリクエストが契約に合わない場合も、返されたレスポンスが契約に合わない場合も、RSpec が失敗します。
レスポンスでは本文の型、必須項目、文字数、enum に加え、定義された HTTP ステータスと Content-Type を検証します。
openapi_first の既定で例外扱いされる未知の 404 と 500 も、このサンプルでは除外しません。

不正入力のテストには `invalid_request: { method: "POST", path: "/api/tasks", error: :invalid_body }` のように、意図したメソッド、パス、検証エラーを指定します。
その組み合わせだけを期待した不正リクエストとして許可し、実際に検証エラーを観測したことも確認します。
この指定によってエラーレスポンスの検証が省略されることはありません。

openapi_first 4.2.0 では Content-Type の照合で操作を選択できなかった 415 のレスポンスを、通常の観測処理だけでは検証できません。
サポートファイル内の小さな補助処理が同じメソッドとパスの JSON 操作を選び、実際に返った 415 のステータス、Content-Type、本文を同じ契約で検証します。
入力のスキーマ検証自体は openapi_first が担当します。

## API 契約、DB 制約、業務動作の違い

契約に合うレスポンスを返していても、値が DB に保存されていない実装はあり得ます。
そのため request spec は契約に加えて保存結果も確認し、不正入力で保存や更新が起きないことを確認します。

| 検証対象 | このサンプルで確かめること | 主な担当 |
| --- | --- | --- |
| API 契約 | title の型と文字数、status の enum、必須項目、クエリ、パス、HTTP ステータス、Content-Type | TypeSpec、OpenAPI、openapi_first |
| 保存する値の整合性 | モデルで title の 1〜100 文字と status を検証し、DB でも null、空の title、不正な status を拒否 | モデル検証、SQLite の NOT NULL と CHECK、model spec |
| 業務動作 | todo で作成、保存済みタスクの一覧、絞り込み、指定タスクの詳細、指定項目だけの更新、404、不正入力で変更しない | コントローラー、Active Record、request spec |

DB 制約は API 以外のコードから直接書き込まれた場合にも効きます。
status の enum は、API の契約と DB の両方で検証します。
title の 1〜100 文字は API とモデルで検証し、DB は空でないバイト列を CHECK 制約で保証します。
SQLite の文字列 `length` は途中の NUL 文字で数え終えるため、DB では文字数の代わりに BLOB として長さを確認し、API が許可する文字列を余分に拒否しないようにしています。
TypeSpec から DB の migration、モデル、業務処理を生成する構成にはしていません。

## デモ 1：正常なタスク作成

サーバーを起動し、別のターミナルで次を実行します。

```sh
curl -i http://localhost:3000/api/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"契約テストを読む"}'
```

201 と `{"id":1,"title":"契約テストを読む","status":"todo"}` のような JSON が返ります。
id は DB の状態によって変わります。
画面の一覧を更新するか、GET で保存結果を確認します。

```sh
curl -i http://localhost:3000/api/tasks
```

返された id を `task_id` に設定し、詳細と部分更新も試せます。
タイトルを送っていない更新では、元のタイトルが残ります。

```sh
task_id=1
curl -i "http://localhost:3000/api/tasks/$task_id"
curl -i -X PATCH "http://localhost:3000/api/tasks/$task_id" \
  -H 'Content-Type: application/json' \
  -d '{"status":"done"}'
curl -i 'http://localhost:3000/api/tasks?status=done'
```

## デモ 2：TypeSpec の制約による入力の拒否

画面の入力制約を通らないリクエストも、curl なら直接送れます。
次の入力はすべて 400 と `application/problem+json` を返します。
一覧を再取得し、タスクが増えていないことを確認してください。

```sh
# 必須の title がない
curl -i http://localhost:3000/api/tasks \
  -H 'Content-Type: application/json' -d '{}'

# 空文字
curl -i http://localhost:3000/api/tasks \
  -H 'Content-Type: application/json' -d '{"title":""}'

# 101 文字。Ruby 標準の JSON で本文を作る
ruby -rjson -e 'puts({ title: "a" * 101 }.to_json)' | \
  curl -i http://localhost:3000/api/tasks \
    -H 'Content-Type: application/json' --data-binary @-

# 不正な status による更新。デモ 1 の task_id を使う
curl -i -X PATCH "http://localhost:3000/api/tasks/$task_id" \
  -H 'Content-Type: application/json' -d '{"status":"paused"}'

# enum は一覧のクエリにも使う
curl -i 'http://localhost:3000/api/tasks?status=paused'

# title の null は許可していない
curl -i http://localhost:3000/api/tasks \
  -H 'Content-Type: application/json' -d '{"title":null}'
```

JSON 以外の Content-Type では 415 を確認できます。

```sh
curl -i http://localhost:3000/api/tasks \
  -H 'Content-Type: text/plain' -d '{"title":"保存されない"}'
```

## デモ 3 と 4 に使う作業コピー

ここからは一時ディレクトリの作業コピーを使います。
元のリポジトリ、DB、未コミットの変更を保持したまま、レスポンスを壊す実験と仕様変更を行えます。
事前に元のリポジトリで `bin/setup` を済ませ、同じターミナルで次を実行してください。
コピーには依存ディレクトリへのシンボリックリンクを置き、コードと DB はコピー側のものを使います。
デモ中は依存の追加や更新は行いません。

```sh
sample_root=$(pwd)
exercise_root=$(mktemp -d "${TMPDIR:-/tmp}/tasks-contract-exercise.XXXXXX")
rsync -a \
  --exclude='.git' --exclude='.serena' \
  --exclude='vendor' --exclude='node_modules' \
  --exclude='storage' --exclude='tmp' --exclude='log' \
  --exclude='coverage' \
  "$sample_root/" "$exercise_root/"
ln -s "$sample_root/vendor" "$exercise_root/vendor"
ln -s "$sample_root/node_modules" "$exercise_root/node_modules"
cd "$exercise_root"
mkdir -p storage tmp log
bin/rails db:prepare
bundle exec rspec
```

以後のコマンドはすべて作業コピー内で実行します。
`rsync` は macOS に付属し、Linux では OS のパッケージとして利用できます。

## デモ 3：必須項目を返さない実装ミス

`task_json` の返却項目から `status` を外します。
変更は次の 1 行です。

```diff
-      task.attributes.slice("id", "title", "status")
+      task.attributes.slice("id", "title")
```

ファイルを個別に退避してから、次のコマンドで変更できます。

```sh
cp app/controllers/api/tasks_controller.rb "$exercise_root/tasks_controller.before-demo3.rb"
ruby <<'RUBY'
path = "app/controllers/api/tasks_controller.rb"
source = File.read(path)
before = 'task.attributes.slice("id", "title", "status")'
after = 'task.attributes.slice("id", "title")'
abort "Expected serializer line was not found" unless source.include?(before)
File.write(path, source.sub(before, after))
RUBY
bundle exec rspec
```

RSpec が失敗し、`OpenapiFirst::ResponseInvalidError` と `Response body is invalid: object at root is missing required properties: status` のような検証エラーが表示されます。
一覧レスポンスでは、エラーの位置が `/0` などの配列要素になります。
構文エラー、依存の不足、DB の準備不足で失敗した場合は、このデモで確認したい契約違反とは異なるので原因を直してください。

退避したコントローラーだけを戻し、テストが成功することを確かめます。

```sh
cp "$exercise_root/tasks_controller.before-demo3.rb" app/controllers/api/tasks_controller.rb
bundle exec rspec
```

## デモ 4：レスポンスに priority を追加する仕様変更

初版にない `priority` を、レスポンスの必須項目に追加します。
この演習では保存時の既定値を `normal` とし、API の作成と更新の入力項目は初版のままにします。
レスポンス契約の変更と、保存、返却、テストの変更を順に進めます。

### 1. TypeSpec のレスポンスを変更する

`api/main.tsp` に enum を追加し、レスポンスの `Task` に必須項目を追加します。
`CreateTask` と `UpdateTask` には追加しません。

```typespec
enum TaskPriority {
  low,
  normal,
  high,
}

// Boolean false preserves sealing and lets Redoc display closed objects correctly.
@extension("unevaluatedProperties", false)
model Task {
  id: int64;
  title: TaskTitle;
  status: TaskStatus;
  priority: TaskPriority;
}
```

次のコマンドで、この変更を加えられます。

```sh
ruby <<'RUBY'
path = "api/main.tsp"
source = File.read(path)
before = <<~TSP.chomp
  // Boolean false preserves sealing and lets Redoc display closed objects correctly.
  @extension("unevaluatedProperties", false)
  model Task {
    id: int64;
    title: TaskTitle;
    status: TaskStatus;
  }
TSP
after = <<~TSP.chomp
  enum TaskPriority {
    low,
    normal,
    high,
  }

  // Boolean false preserves sealing and lets Redoc display closed objects correctly.
  @extension("unevaluatedProperties", false)
  model Task {
    id: int64;
    title: TaskTitle;
    status: TaskStatus;
    priority: TaskPriority;
  }
TSP
abort "Expected Task model was not found" unless source.include?(before)
File.write(path, source.sub(before, after))
RUBY
npm run openapi
npm run openapi:check
bundle exec rspec
```

同期確認は成功しますが、RSpec は `OpenapiFirst::ResponseInvalidError` で失敗します。
OpenAPI に必須の `priority` が追加され、Rails がまだ返していないためです。
`openapi/openapi.yaml` の `Task` にある `required` と `priority` の enum を見ると、変更された契約を確認できます。

### 2. 保存先と返却処理を更新する

既存データにも値が入ることを試すため、変更前のテーブルに 1 件作成します。
続いて migration を作り、NOT NULL のカラム、既定値、enum の CHECK 制約を追加します。

```sh
bin/rails runner 'Task.create!(title: "移行前のタスク", status: "todo")'
cat > db/migrate/20261009000001_add_priority_to_tasks.rb <<'RUBY'
class AddPriorityToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :priority, :string, default: "normal", null: false
    add_check_constraint :tasks,
      "priority IN ('low', 'normal', 'high')",
      name: "tasks_priority_allowed"
  end
end
RUBY
bin/rails db:migrate
```

`Task` にモデル検証を追加し、コントローラーの返却項目に `priority` を加えます。
DB の既定値を使うため、新規作成と既存テストの `Task.create!` に値を重複指定する必要はありません。

```diff
 # app/models/task.rb
   validates :status, inclusion: { in: %w[todo doing done] }
+  validates :priority, inclusion: { in: %w[low normal high] }

 # app/controllers/api/tasks_controller.rb
-      task.attributes.slice("id", "title", "status")
+      task.attributes.slice("id", "title", "status", "priority")
```

```sh
ruby <<'RUBY'
model_path = "app/models/task.rb"
model = File.read(model_path)
model_before = '  validates :status, inclusion: { in: %w[todo doing done] }'
model_after = model_before + "\n  validates :priority, inclusion: { in: %w[low normal high] }"
abort "Expected status validation was not found" unless model.include?(model_before)
File.write(model_path, model.sub(model_before, model_after))

controller_path = "app/controllers/api/tasks_controller.rb"
controller = File.read(controller_path)
controller_before = 'task.attributes.slice("id", "title", "status")'
controller_after = 'task.attributes.slice("id", "title", "status", "priority")'
abort "Expected serializer line was not found" unless controller.include?(controller_before)
File.write(controller_path, controller.sub(controller_before, controller_after))
RUBY
bin/rails runner 'task = Task.find_by!(title: "移行前のタスク"); abort "Existing task was not migrated" unless task.priority == "normal"; puts task.attributes.slice("id", "title", "status", "priority")'
```

### 3. 保存結果と返却値のテストを追加する

request spec で、レスポンスに加えて DB の値も確認します。
このテストにも既存の契約検証が適用されます。

```sh
cat > spec/requests/priority_spec.rb <<'RUBY'
require "rails_helper"

RSpec.describe "Task priority", type: :request do
  it "persists and returns the default priority" do
    post "/api/tasks", params: { title: "Priority exercise" }, as: :json

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body.fetch("priority")).to eq("normal")
    expect(Task.find(body.fetch("id")).priority).to eq("normal")
  end
end
RUBY
bundle exec rspec
bin/check
```

契約、保存、返却が揃えばテストが成功します。
既存の request spec も、カラムの既定値により初期データの `priority` が `normal` となり、新しいレスポンス契約で検証されます。

### 4. 初版へ戻る

元のディレクトリへ戻れば、初版の契約と実装で作業できます。
元のファイルと DB は一時コピーの演習で変更していません。
一時コピーは調べ直せるよう、そのまま残します。

```sh
cd "$sample_root"
bin/check
```

復元にコミットや `git reset` は使いません。
納品する初版にも `priority`、故意に壊したレスポンス、常に失敗するデモ用テストは含めません。

## Rails の生成と省いた機能

Rails 8.1 系は公式の保守対象である安定版を採用しました。
生成時に `rails _8.1.3.1_ new --help` で利用可能なオプションを確認し、用意済みの同名空ディレクトリ内で、次のコマンドを実行しました。
`_8.1.3.1_` の指定により、この版の Rails コマンドを選びます。

```sh
rails _8.1.3.1_ new . \
  --api \
  --minimal \
  --database=sqlite3 \
  --no-rc \
  --skip-bundle \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-job \
  --skip-active-storage \
  --skip-action-cable \
  --skip-asset-pipeline \
  --skip-javascript \
  --skip-hotwire \
  --skip-jbuilder \
  --skip-test \
  --skip-system-test \
  --skip-bootsnap \
  --skip-dev-gems \
  --skip-solid \
  --skip-kamal \
  --skip-thruster \
  --skip-docker \
  --skip-rubocop \
  --skip-brakeman \
  --skip-bundler-audit \
  --skip-ci \
  --skip-decrypted-diffs \
  --quiet
```

Active Record、SQLite、JSON API のルーティングとコントローラーを残し、メール、ジョブ、ファイル添付、WebSocket、アセットのビルド、Hotwire、デプロイ用の設定を省いています。
`--skip-javascript` は Rails の導入機構を省く指定であり、`public/app.js` に置く標準 JavaScript は配信できます。
`--skip-test` で Minitest の雛形を省き、rspec-rails の導入後に次を実行して RSpec を初期設定しました。

```sh
bin/rails generate rspec:install
```

`--skip-ci` で標準の追加ツールを前提とするワークフローを省き、`.github/workflows/check.yml` に、このアプリ用の 1 つのワークフローを用意しました。
CI は Ruby と Node.js を準備し、lockfile に基づいて依存をインストールして、`bin/check` で OpenAPI の同期確認、API ドキュメントの生成、`bundle exec rspec` を実行します。
実行方法を変える専用テストランナーや、CI のための gem は追加していません。

## 直接依存と lockfile

Ruby の直接依存は次のものだけです。
`rspec-rails` は development と test のグループにあります。

| gem | 必要な理由 |
| --- | --- |
| `rails` | API アプリ、Active Record、ルーティング、JSON 返却、migration |
| `sqlite3` | SQLite の接続と永続化 |
| `puma` | `bin/rails server` で使う Web サーバー |
| `openapi_first` | 入力検証と契約テスト |
| `rspec-rails` | Rails の request spec と model spec |
| `tzinfo-data` | Windows と JRuby で必要なタイムゾーンデータ（対象プラットフォームのみ） |
| `json` | 既存の推移的依存を 2.21.2 に制約し、Rails の JSON 引数との互換性を保つ |

Rails 8.1.3.1 の JSON デコーダーはオプションを位置引数で渡しますが、json 3.0 ではキーワード引数に変わり、その組み合わせでは正常な JSON リクエストも失敗します。
そのため、もともと依存グラフにある json を 2.21.2 に固定しています。
Rails 内部の呼び出しを別の標準 API へ差し替える変更や monkey patch を加えず、互換性のある版を選ぶための宣言です。

Node.js の直接依存は、TypeSpec の公式パッケージ 4 個と、API ドキュメント生成用の Redocly CLI を devDependencies に置いています。
TypeSpec のパッケージは必要な peer dependency を満たし、バージョンをすべて 1.17.0 に揃えています。
`@redocly/cli` は 2.61.0 に固定し、既存の OpenAPI からドキュメントを生成するために追加しています。

| npm パッケージ | 必要な理由 |
| --- | --- |
| `@typespec/compiler` | TypeSpec のコンパイルと `tsp` コマンド |
| `@typespec/http` | HTTP のメソッド、パス、クエリ、本文、ステータスの定義 |
| `@typespec/openapi` | OpenAPI のメタデータと openapi3 の必須依存 |
| `@typespec/openapi3` | OpenAPI 3.1 の YAML 出力 |
| `@redocly/cli` | OpenAPI からブラウザー用 API ドキュメントを生成 |

推移的依存の `@scalar/json-magic` が指定する `undici 7.24.4` は、npm の `overrides` で同じ major の修正版 `7.29.1` に固定しています。
これは追加の直接ライブラリではなく、必要な推移的依存の修正です。
`--force` で依存の不整合を隠したり、lockfile を手編集して依存を削ったりはしていません。
Rails の gem に含まれる未使用コンポーネントの推移的依存は、Rails を分解せずそのまま残しています。

依存の正確な解決結果は `Gemfile.lock` と `package-lock.json` に保存しています。
FactoryBot、Faker、Swagger UI、専用シリアライザー、フロントエンドフレームワーク、CSS フレームワーク、SDK 生成器は使っていません。
テストデータは `Task.create!`、操作画面は HTML、CSS、標準 JavaScript の `fetch` で用意しています。

## 作成時の検証結果

初版の `bin/check` は OpenAPI の同期確認と RSpec 35 件が成功しました。
画面操作、4 API、不正入力、レスポンス契約違反、priority の仕様変更と実装修正をローカルで検証しました。
生成コマンド、使用バージョン、各デモの失敗・成功、保持した検証用 DB と未実施項目は [検証報告](docs/verification.md) に記録しています。
現在の DB は `storage/tasks_development.sqlite3` と `storage/tasks_test.sqlite3` です。
初版のローカル検証時点では、GitHub Actions のリモート実行は行っていませんでした。
その後、初回公開後の [GitHub Actions の check（実行 37895579726）](https://github.com/AudioStakes/rails-typespec-openapi-first-sample/actions/runs/37895579726) が成功しました。
本番デプロイは行っていません。

## 参照した公式資料

- [Rails 8.1 の API モード](https://guides.rubyonrails.org/v8.1/api_app.html)：API 用の構成とミドルウェア。
- [Rails 8.1 のコマンドライン](https://guides.rubyonrails.org/v8.1/command_line.html)：生成、起動、migration。
- [Rails の保守方針](https://guides.rubyonrails.org/maintenance_policy.html)：採用する安定版のサポート確認。
- [TypeSpec の公式リポジトリ](https://github.com/microsoft/typespec)：パッケージとバージョンの確認。
- [TypeSpec の HTTP 操作](https://typespec.io/docs/libraries/http/operations/)：リクエストとレスポンスのモデル化。
- [TypeSpec の組み込み decorator](https://typespec.io/docs/standard-library/built-in-decorators/)：文字数などの制約。
- [OpenAPI 3 emitter の設定](https://typespec.io/docs/emitters/openapi3/reference/emitter/)：出力先、OpenAPI 3.1、`seal-object-schemas`。
- [Redocly CLI の build-docs](https://redocly.com/docs/cli/commands/build-docs)：OpenAPI からの HTML 生成、出力先、タイトル、Google Fonts の無効化。
- [openapi_first 4.2.0](https://github.com/ahx/openapi_first/tree/v4.2.0)：登録、リクエスト検証、テストの観測。
- [openapi_first 4.2.0 の Rails サンプル](https://github.com/ahx/openapi_first/tree/v4.2.0/examples/rails_app)：Rails への組み込み。
- [rspec-rails 8.0.4](https://github.com/rspec/rspec-rails/tree/v8.0.4)：Rails に対応するテスト機能。
- [json 3.0.2 の変更履歴](https://github.com/ruby/json/blob/v3.0.2/CHANGES.md)：JSON オプションの引数変更。
- [GitHub Actions の Ruby のビルドとテスト](https://docs.github.com/en/actions/tutorials/build-and-test-code/ruby)：最小ワークフローの作り方。
