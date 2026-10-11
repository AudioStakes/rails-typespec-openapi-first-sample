# openapi_first の公式推奨と記事の整合性監査

監査日：2026-10-11。
対象は `docs/article.md`、README、TypeSpec 定義、生成済み OpenAPI、Rails の実装、RSpec、生成スクリプト、CI である。
作業開始時のブランチは `main`、HEAD は `1eeec9922e868076ed8eb47fff40351893b324cc`、未コミット変更と未追跡ファイルはなかった。
監査作業中は commit、push、PR 作成、Zenn への公開を行わなかった。
監査後の追加依頼により、アプリ・テスト・README・この監査記録をコミットと push の対象にし、記事原稿の変更はローカルに残す。

## 総合評価

変更前から、OpenAPI の一度の登録、実行時の `RequestValidation`、RSpec の `Test.setup` と `Test.observe(Rails.application)`、TypeSpec から生成した契約の同期チェックは公式の利用方法と整合していた。
本番の `ResponseValidation` を常時有効にする構成ではなく、公式 README が優先する契約テストで出力を検証している。[v4.2.0 のレスポンス検証](https://github.com/ahx/openapi_first/blob/v4.2.0/README.md#response-validation)、[契約テストの実装](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test.rb)

重要な不一致は、検証済み query と Rails が解釈した query の違いだった。
`GET /api/tasks?status[extra]=done` は通常の検証で未定義 query として扱われる一方、変更前のコントローラーは Rails の Hash を `status` の値として DB 検索に使い、例外になった。
検証済みの値をコントローラーでも利用する修正と、通常の入力検証を通す回帰テストで対応した。

記事と README では、公式の推奨、用途に応じた選択、サンプルの追加設定を区別する。
特に例外を抑制する既定値、異常系テストの限定的な許可、未定義 query の扱い、415 の補完検証、カバレッジと保証範囲を明確にする。

## 実際に確認したバージョンと生成経路

lockfile だけでなく、Bundler でロードする gem とインストール済み npm パッケージのバージョンも確認した。

| 対象 | バージョン |
| --- | --- |
| Ruby / Bundler | 4.0.6 / 4.0.16 |
| Rails / Rack | 8.1.3.1 / 3.2.7 |
| openapi_first / json_schemer | 4.2.0 / 2.5.0 |
| rspec-rails / rspec-core | 8.0.4 / 3.13.6 |
| rspec-expectations / rspec-mocks / rspec-support | 3.13.5 / 3.13.8 / 3.13.7 |
| Node.js | 24.18.0 |
| TypeSpec compiler / http / openapi / openapi3 | すべて 1.17.0 |
| 生成する OpenAPI | 3.1.0 |
| Swagger UI | 5.33.1（継続） |

正本は `api/main.tsp`、出力設定は `tspconfig.yaml` である。
`npm run openapi` が OpenAPI を生成してローカルの Swagger UI に配置する。
`bin/check` は一時ディレクトリで再生成して保存済み YAML とバイト単位で比較し、UI の配置と RSpec を実行する。
CI も同じ `bin/check` を使う。
出力は `/api/tasks` の GET/POST と `/api/tasks/{id}` の GET/PATCH、サーバー指定は同一オリジンの `/` であり、Rails の routes と対応する。
`seal-object-schemas: true` は本文とレスポンスの object を閉じるための、このサンプルの選択である。[公式 emitter の設定](https://typespec.io/docs/emitters/openapi3/reference/emitter/)

## 主な指摘と対応

| 分類 | 問題点または確認対象 | 公式の根拠 | 判断と修正内容 | 確認結果 |
| --- | --- | --- | --- | --- |
| 必須修正 | 検証済み query と Rails の query 解釈が異なり、未定義の nested query が DB 検索に使われる | [ValidatedRequest](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/validated_request.rb) | controller は env の検証結果の `parsed_query`、`parsed_body`、`parsed_path_parameters` を使う。代入属性の `slice` は維持する | 修正前の失敗を回帰テストで再現し、修正後に成功することを確認 |
| 必須修正（説明） | `Test.setup` の設定と実際の観測を区別する必要がある | [Test.setup と Test.observe](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test.rb) | 設定だけでは HTTP を観測せず、現在の `observe` が app の前後で入出力を照合することを記事に明記する | 必須 `completed` 追加の演習で、同じ request spec が返却漏れを検出することを再検証する |
| 必須修正（説明） | `ignored_unknown_status` という名前から、未知の status だけを無視すると誤解しやすい | [Configuration#raise_response_error?](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test/configuration.rb) | 既定の `[401, 404, 500]` は定義済み status の不正な応答も例外抑制する。サンプルの `[]` は不正な 404 応答をその場で例外にするために維持する | 公式ソースとテストで既定値と抑制条件を確認。サンプルの 404 本文にも契約チェックが適用される |
| 必須修正（説明） | 本番の未知 query 許容と Test の追加チェックは異なる | [Test の query check](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test.rb)、[ValidatedRequest](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/validated_request.rb) | README に通常の入力検証と Test の厳しさを区別して記す。回帰例は対象の未知 query だけ Test の追加例外を抑制し、本番の入力検証と出力照合を維持する | native の検証済み値を使えば、未定義 query は検索条件に入らない |
| 用途に応じた改善 | 415 の場合は request の media type 照合に失敗し、通常の response observer が照合しない | [Definition#validate_response](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/definition.rb) | API の契約に含めた 415 は検証を維持する。app 全体への追加 prepend を削除し、415 の異常系テストだけで同じ操作の response 定義を公式 API へ照合する | 2つの 415 テストで実行する。照合対象が見つからない `nil` も失敗させる |
| 用途に応じた判断（維持） | 既知の不正入力は Test の設定だけで必ず即例外になるわけではない | [Test.setup の request hook](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test.rb) | 通常例では不正入力を失敗させ、意図した異常系だけ method/path/error の一致で許可する補助 hook を維持する | 異常系で 4xx と本文、DB の不変を確認する。非 API の除外も未知のリクエストに限定する |
| 用途に応じた判断（維持） | HTML、OpenAPI、API を同じ Rails で配信する | [RequestValidation の適用](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/middlewares/request_validation.rb)、[Rails on Rack](https://guides.rubyonrails.org/v8.1/rails_on_rack.html) | `/api` 以下だけ native middleware を呼ぶ既存 subclass を維持し、サンプル固有の適用範囲と明記する | 実際の middleware stack を確認した。定義の `only` や Test の除外設定との混同はない |
| 必須修正（説明） | API カバレッジや出力検証を業務の正しさ、値や権限の網羅、更新の取消と取り違えない | [Coverage の Plan](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test/coverage/plan.rb)、[observe の Callable](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test/callable.rb) | 契約に適合した定義を少なくとも一度実行したかを表すことと、別に業務 expectation が必要なことを明記する。処理後の検証自体は DB 更新を取り消さない | 既存の業務結果と不正入力による副作用遮断のテストを維持する |

公式 README の「unknown response status」という説明と、実装の status 単位の例外抑制は区別して判断した。
`ignored_unknown_status` はカバレッジの除外設定ではない。
例外を抑えた不正な応答もカバレッジでは追跡するため、終了時のカバレッジ判定で失敗する可能性はある。
`skip_coverage` と `skip_response_coverage` はカバレッジの母数を変える設定であり、検証エラーの例外抑制とは独立している。
このサンプルではカバレッジを除外する設定を追加していない。

カバレッジの母数は、除外後の各操作の request media type ごとの定義と、response status/media type ごとの定義の合計である。
各定義が少なくとも一度有効に検証されれば、その定義は達成したと扱われる。
schema の全分岐、全入力値、業務条件を試したことを表すものではない。[Plan の計算](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test/coverage/plan.rb#L15-L24)、[公式 coverage テスト](https://github.com/ahx/openapi_first/blob/v4.2.0/spec/test/coverage/plan_spec.rb#L124-L160)

公式 v4.2.0 の README と7つの Ruby ファイル（計8ファイル）は、インストール済み gem とバイト単位で一致した。
README と実装の解釈が分かれやすい点は、実装と小さな動作確認を根拠に判断した。
既知の不正 query は `Test.setup` だけでは例外にならず、nested な未知 query では Test の追加チェックによる例外になった。
既知の 404 で本文が不正な応答は既定値では例外が抑制され、`ignored_unknown_status = []` では `ResponseInvalidError` になった。
415 の通常のレスポンス照合が `nil` になることも、対応する request の media type 照合を含めて確認した。

## 変更ファイルと意図

| ファイル | 意図と対応関係 |
| --- | --- |
| `app/controllers/api/tasks_controller.rb` | 検証結果を query、本文、path の値の取得元に統一する。登録した契約が判定した値を処理に使い、更新属性の限定は保持する |
| `spec/requests/tasks_spec.rb` | nested query の回帰例を追加し、本番 middleware と公式 observer を通す。415 のエラー本文の expectation からだけ補完検証を呼ぶ |
| `spec/support/openapi_contract.rb` | 正確な異常系の許可と `ignored_unknown_status = []` を保持する。415 の app 全体 prepend を削除し、短い helper に限定する |
| `docs/article.md` | 既存の主題と結論を述べる見出しを維持し、公式推奨、検証範囲、既定値とサンプルの選択を明確にする。演習ログは修正後の実測に合わせる |
| `README.md` | 実行時と Test の違い、検証済み値、415 の補完、カバレッジの意味を説明し、監査記録へリンクする |
| `docs/openapi-first-audit.md` | この監査の根拠、分類、修正と確認結果、維持した判断を記録する |

`api/main.tsp`、`tspconfig.yaml`、生成済み `openapi/openapi.yaml`、lockfile、CI は変更する必要がなかった。
OpenAPI は既存の生成コマンドで再生成し、正本から同じ内容を得られることを確認した。

## 検証結果

| 確認 | 実行コマンドや方法 | 結果 |
| --- | --- | --- |
| 変更前の基準 | `bin/check` | OpenAPI 同期一致、UI 配置成功、35 examples / 0 failures、exit 0 |
| Ruby と gem の実バージョン | `bundle exec ruby` から `RUBY_VERSION` と `Gem.loaded_specs` を取得 | 上記のバージョン表と一致 |
| npm の実バージョン | インストール済み各パッケージの `package.json` を確認 | TypeSpec と emitter は 1.17.0 |
| 実際の適用順序 | `bin/rails middleware` | `ApiContractRequestValidation` は routes の前、静的ファイル配信は前段 |
| 正本からの生成 | `npm run openapi` | TypeSpec のコンパイルと UI 配置成功。追跡している YAML に差分なし |
| 修正後の既存チェック | `bin/check` | OpenAPI 同期一致、UI 配置成功、36 examples / 0 failures、exit 0 |
| query の回帰確認 | 新しい request spec。対象 query だけ Test の追加例外を抑制し、通常の `get` で実行 | 元の index をプロセス内で再現すると TypeError で失敗。修正後は 200 と両 status のタスクを確認し、DB は不変。本番 middleware と出力 observer は維持 |
| request spec の対象検証 | `bundle exec rspec spec/requests/tasks_spec.rb` | 33 examples / 0 failures、exit 0 |
| 記事の仕様変更 | 一時コピーで `Task` に `completed: boolean` を追加し、`npm run openapi`、`bundle exec rspec` | 36 examples / 12 failures。12件すべてが `completed` の欠落による `ResponseInvalidError`。契約カバレッジ 75% で終了コード 2 |
| 記事の実装修正 | 同じコピーで serializer に派生 `completed` を追加して `bin/check` | テストファイルを変えず、同期一致と 36 examples / 0 failures、exit 0 |
| README の実装破壊 | 同じコピーを基本仕様へ戻し、serializer の `status` を削除して `bundle exec rspec` | 36 examples / 12 failures。`status` の欠落を検出し、契約カバレッジ未達で exit 2 |
| README の復旧 | serializer を戻し、`bin/check` | 同期一致と 36 examples / 0 failures、exit 0 |
| 差分レビュー | 公式資料担当の独立レビュー、実装担当による記事との照合、root の差分確認 | 即時例外と終了時カバレッジの区別、監査対象ファイル数の記述を補正。重要な未解決指摘なし |

演習コピーは `/private/tmp/openapi-first-audit.hghbBV` で、依存だけを元のリポジトリと共有し、コードと DB は分離した。
最終的にコピーも基本仕様へ戻した。
テストの出力は `tmp/openapi-audit-*.log` にあり、Git の対象外である。
元の開発 DB を作り直したり、記事の `completed` 演習を元の TypeSpec に反映したりしていない。

ローカルでの RSpec は coverage 集計の DRb ソケットを開くため、通常の sandbox では bind が拒否される。
必要な権限で実行して上記の結果を確認した。
これはテストやライブラリの失敗とは区別した。
独立した lint の設定はなく、既存の `bin/check` と `git diff --check` を検証対象にした。
監査時点では CI のジョブと同じコマンドをローカルで実行し、push は行わなかったため、新しい GitHub Actions の実行は起動していない。
Swagger UI のコードと依存は変更しておらず、今回ブラウザーでの再検証は行っていない。

## 維持する判断と監査範囲

- `RequestValidation` と公式の `Test.observe` を維持する。テスト中も実際の入力遮断を通す。
- `ignored_unknown_status = []` を維持する。不正な 404 の本文もその場で例外にするためである。
- `/api` 以下にだけ入力検証を適用する小さな subclass を維持する。静的ファイルは middleware の前段で返され、subclass はそれ以外の非 API リクエストも契約外に置く、サンプルの設計選択である。gem の設定や公式の汎用ルーティング API として紹介しない。
- RSpec、依存のバージョン、Swagger UI、TypeSpec の正本と生成経路を維持する。
- Sentry、認証、CORS、SSE、ファイル配信は既存の対象範囲に含まれず、新規導入しない。外部の監視サービスへの送信も行わない。
- API カバレッジは入力値、業務分岐、認証や認可の網羅を意味しない。実行しなかった経路の出力も保証しない。

この依頼の範囲で、追加判断を要する重要な未解決事項はない。

## 参照した一次資料

- [openapi_first v4.2.0 README](https://github.com/ahx/openapi_first/blob/v4.2.0/README.md)
- [v4.2.0 の Rails サンプル](https://github.com/ahx/openapi_first/tree/v4.2.0/examples/rails_app)
- [Test の設定と実装](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test.rb)
- [契約テストの設定と既定値](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/test/configuration.rb)
- [RequestValidation](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/middlewares/request_validation.rb)
- [ResponseValidation](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/middlewares/response_validation.rb)
- [ValidatedRequest](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/validated_request.rb)
- [Definition](https://github.com/ahx/openapi_first/blob/v4.2.0/lib/openapi_first/definition.rb)
- [v4.2.0 CHANGELOG](https://github.com/ahx/openapi_first/blob/v4.2.0/CHANGELOG.md)
- [Rails 8.1 on Rack](https://guides.rubyonrails.org/v8.1/rails_on_rack.html)
- [TypeSpec の OpenAPI emitter](https://typespec.io/docs/emitters/openapi3/reference/emitter/)
