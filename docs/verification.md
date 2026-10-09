# 作成・検証結果

2026年10月9日（日本時間）にローカルで検証しました。

作成先は `/Users/satoudaisuke/Documents/ChatGPT/rails-typespec-openapi-first-sample` です。
同名の用意済みディレクトリと未コミットのGitリポジトリを使用し、Rails生成時にもGit初期化を実行しました。
初版のローカル検証時点では、コミット、push、リモート作成、Pull Request作成は行っていませんでした。
その後の依頼により、[プライベートGitHubリポジトリ](https://github.com/AudioStakes/rails-typespec-openapi-first-sample)を作成しました。

## 使用したバージョン

| ツール | バージョン |
| --- | --- |
| Ruby | 4.0.6 |
| Rails | 8.1.3.1 |
| Bundler | 4.0.16 |
| Node.js | 24.18.0 |
| npm | 11.16.0 |
| TypeSpec compiler/http/openapi/openapi3 | 各1.17.0 |
| OpenAPI | 3.1.0 |
| openapi_first | 4.2.0 |
| rspec-rails | 8.0.4 |
| Puma | 7.2.1 |
| sqlite3 gem / SQLite実体 | 2.9.6 / 3.53.2 |
| json gem | 2.21.2 |

asdfの既存インストールを利用し、プロジェクトのバージョン指定を保存しました。
検証時はNode.js 24.18.0を明示して実行しました。
グローバルのバージョン設定は変更していません。

## 実際の生成コマンド

`rails _8.1.3.1_ new --help` と [Rails公式資料](https://guides.rubyonrails.org/v8.1/command_line.html)を確認し、次を実行しました。

```sh
rails _8.1.3.1_ new . --api --minimal --database=sqlite3 --no-rc --skip-bundle --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-job --skip-active-storage --skip-action-cable --skip-asset-pipeline --skip-javascript --skip-hotwire --skip-jbuilder --skip-test --skip-system-test --skip-bootsnap --skip-dev-gems --skip-solid --skip-kamal --skip-thruster --skip-docker --skip-rubocop --skip-brakeman --skip-bundler-audit --skip-ci --skip-decrypted-diffs --quiet
```

生成された不要なdebug gem、CORS設定、標準CIスクリプトを取り除き、`bin/rails generate rspec:install` を実行しました。

## 直接依存と必要性

Rubyの直接宣言はRails、sqlite3、Puma、openapi_first、rspec-rails、json、Windows/JRuby用のtzinfo-dataです。
Web処理、永続化、サーバー、契約検証、RSpecと、必要な互換性・プラットフォーム対応を担います。
rspec-railsはdevelopment/testグループに限定しています。
jsonは既に依存グラフにあるgemの互換性制約で、Rails 8.1の位置引数による呼び出しとJSON 3のキーワード引数との不一致を避けるため2.21.2へ固定しました。
変更の根拠は [JSON 3の公式変更履歴](https://github.com/ruby/json/blob/v3.0.2/CHANGES.md)と実行時の再現です。

npmの直接依存は公式のTypeSpec compiler/http/openapi/openapi3の4つです。
不要なoptional peerは導入していません。
推移的依存のundiciは修正済みの7.29.1へ固定し、監査結果は0件です。
追加のフロントエンド依存はありません。

## 実施結果

| 確認 | 結果 |
| --- | --- |
| `bin/setup` | frozen Bundler、npm ci、同期確認、DB準備が成功 |
| `bundle exec rspec` / `bin/check` | 通常35件、失敗0件。OpenAPI同期も成功 |
| Rails起動 | 127.0.0.1:3000でPuma起動を確認 |
| 4 API | 作成201、一覧・詳細・更新200、欠落404を確認 |
| 不正入力 | 欠落、空文字、101文字、型、null、enum、未知の本文項目を拒否しDB不変 |
| Content-Type・JSON構文 | 415・400のProblem JSONも契約検証 |
| ブラウザ操作 | 作成、表示、状態変更、絞り込み、通信履歴、エラー表示が成功 |
| 画面幅 | Chromeの1440pxと390pxで横はみ出しなし |
| デモ3 | status欠落で35件中11件失敗。ResponseInvalidErrorの必須status欠落を確認 |
| デモ4の仕様だけ変更 | priority欠落で35件中11件失敗。ResponseInvalidErrorを確認 |
| デモ4の実装修正 | 既存行もnormalへ移行し、追加テストを含む36件が成功。同期も成功 |
| 同期の異常系 | 一時コピーの保存済みYAMLを変えると終了1。比較後もSHA-256が一致し、書き換えなし |
| 初版への復帰 | 元リポジトリのapi/app/specにpriorityがないことを確認 |

レスポンス検証にはopenapi_firstの [Test.observe](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test.rb) を使用しています。
通常リクエストの厳密な入力確認、対象を限定した異常系、ライブラリが検証を省く415レスポンスの補完も行っています。
本番へ常時レスポンス検証middlewareを追加していません。

レビューで見つかったJSON本文とクエリの混合を修正し、GETの絞り込みはクエリ、POST/PATCHの属性はJSON本文から取得します。
また、SQLiteのlengthはNULで数え方が変わるため、DBではNOT NULL・空でないバイト列・状態enumを保証し、1〜100文字はTypeSpecとモデルで検証します。
NULを含む有効な文字列も回帰テストで確認しました。

## 起動と確認

```sh
bin/setup
bin/rails server
# 別ターミナル
bin/check
```

[http://localhost:3000](http://localhost:3000) を開いて操作します。
検証のため起動したサーバーは127.0.0.1:3000で稼働中です。
新しい開発DBには動作確認用の「契約テストを読む」タスク1件があります。
詳細な演習・個別復元手順と全公式参照は [README](../README.md) にあります。

## 未実施と保持したファイル

GitHub Actionsはローカルに1ワークフローを用意しましたが、GitHub上では実行していません。
同じ検証コマンドはローカルで実行済みです。
本番デプロイとChrome以外のブラウザ検証は行っていません。

DB削除は自動承認レビューで、既存データを不可逆に失う操作として拒否されました。
削除せず、元の `storage/development.sqlite3` と `storage/test.sqlite3` を保持しました。
現在の設定は新規の `storage/tasks_development.sqlite3` と `storage/tasks_test.sqlite3` を使用しています。
仕様変更デモも隔離した一時コピーで実行したため、元の仕様・実装・DBにpriority演習の変更は残っていません。
