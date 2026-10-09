# TypeSpecのエコシステムとAPI操作UIの選定

調査日：2026-10-09（日本時間）。
対象：このリポジトリのTypeSpec 1.17.0、OpenAPI 3.1.0、Rails 8.1.3.1、`openapi_first` 4.2.0、Swagger UI 5.33.1。
調査開始時のコミット：`749651f`。
公式ドキュメント、公式リポジトリ、配布元のnpm registryを確認した。
TypeSpec公式リポジトリの主要ソースは、調査時の`62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0`へ参照を固定した。
バージョン情報と機能の説明を別々に照合し、ドキュメントの古いインストール例を最新版の根拠にはしていない。

## 今回採用する構成

このサンプルでは、API操作UIをSwagger UI 5.33.1のまま維持する。
TypeSpecには編集、診断、生成のエコシステムがあり、生成OpenAPIを既存のOpenAPIツールと組み合わせる構成が公式にも示されている。
公式PlaygroundとVS CodeのAPIプレビューもSwagger UIを採用している。[公式OpenAPI紹介](https://typespec.io/openapi/)、[Playground viewer](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/src/react/viewers/index.tsx)、[VS Codeのinitializer](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/typespec-vscode/swagger-ui/swagger-initializer.js)

追加する価値があるのは、仕様を編集するための公式VS Code拡張と、短い仕様を試して共有するPlaygroundである。
これらは任意の補助ツールとして案内する。
Rails側の`openapi_first`とRSpecによる契約検証は、API操作UIやコード生成とは別の役割を持つ。

Scalar 1.73.1は、同じOpenAPIとRails APIで正常系と不正入力の送信を実測できた。
基本的な移行可能性は確認できたが、このサンプルの「仕様を読み、契約違反を観察する」という用途を改善する決定的な利点は今回確認できなかった。
今回展開したTaskモデルでは、Swagger UIのほうが追加プロパティ禁止を明示し、ScalarのCreateTask自動例には制約に反する空のtitleが現れた。
文書の見せ方やAPI clientの機能を主目的にする場合には、再比較する候補になる。

## TypeSpecのツール群とOpenAPIのツール群

TypeSpecには、仕様を記述するためのツールと、仕様から成果物を生成する仕組みがある。
公式のOpenAPI紹介ページは、生成したOpenAPIを既存のOpenAPIエコシステムと組み合わせる使い方を明示している。
Swagger UIを使う現在の構成は、その使い方に沿っている。[公式OpenAPI紹介](https://typespec.io/openapi/)

| 層 | 入力と役割 | 主な選択肢 | このサンプルへの適用 |
| --- | --- | --- | --- |
| TypeSpecの作者向けツール | `.tsp`の編集、静的な診断、生成 | compiler、formatter、linters、VS Code拡張、Visual Studio拡張、Playground | 正本の編集を支援する |
| TypeSpecのemitter | コンパイルした型情報から成果物を生成 | OpenAPI、JSON Schema、Protobuf、GraphQL、各言語のclient/server | OpenAPIを生成する |
| OpenAPIの利用ツール | 生成OpenAPIを読み、表示、実行、検証などを行う | Swagger UI、Scalarなど | RailsのAPIを閲覧して操作する |
| Railsの契約検証 | 実際のHTTP request/responseとOpenAPIを照合 | このサンプルの`openapi_first` | 入力の拒否とRSpecでの出力検証を行う |

TypeSpecのemitterは、コンパイラのAPIを通して型情報を読み、別の形式の成果物を出力するライブラリである。
この設計によって、同じ仕様から複数の成果物を生成できる。
emitterの追加と、API操作UIの選定は、異なる判断になる。[公式emitterの説明](https://typespec.io/docs/extending-typespec/emitters-basics/)

## 公式Playgroundと独立したAPI操作UI

公式Playgroundは、ブラウザでTypeSpecを編集してコンパイル結果を確認するツールである。
公式サイトの設定は`@typespec/openapi3`を既定emitterとし、HTTP、OpenAPI、JSON Schema、GraphQL、Protobuf、client/serverのライブラリなどを読み込む。[公式サイトのPlayground設定](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground-website/src/config.ts)

そのOpenAPI用viewerは、Swagger UIを組み込んでいる。
`SwaggerUIViewer`が出力ファイルの文字列を受け取り、`swagger-ui-dist`の`SwaggerUIBundle`へ渡す実装になっている。
今回確認した公式実装で、Scalarを組み込むviewerや、TypeSpec独自のHTTP実行エンジンは見つからなかった。[viewerの登録](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/src/react/viewers/index.tsx)、[Swagger UIの呼び出し](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/src/react/viewers/react-wrapper.tsx)

| 項目 | 確認した機能 | 根拠 |
| --- | --- | --- |
| 仕様編集 | TypeSpecの編集とコンパイル結果の表示 | [Playgroundパッケージ](https://github.com/microsoft/typespec/tree/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground) |
| OpenAPIプレビュー | 生成したOpenAPIをSwagger UIで表示 | [Swagger UI viewer](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/src/react/viewers/index.tsx) |
| 共有 | TypeSpec本文、`tspconfig`、選択viewerなどを圧縮してURL queryへ保存 | [URL保存の実装](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/src/react/standalone.tsx) |
| 自前のPlayground | Reactコンポーネントとして組み込み、独自ライブラリや表示を構成できる | [Playground README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/README.md) |
| ローカル起動 | 公式サイトパッケージを`npm start`、`npm run preview`、`npm run build`で実行できる | [サイトREADME](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground-website/README.md) |
| 配布版 | `@typespec/playground` 0.18.0。React、Monaco、Fluent UIなどに依存し、Swagger UIの依存指定は`^5.32.14` | [0.18.0の配布メタデータ](https://registry.npmjs.org/@typespec%2fplayground/0.18.0) |

APIを呼び出す能力は、埋め込まれたSwagger UIと、出力OpenAPIの`servers`設定に依存する。
ブラウザから実サーバーへ到達できることも必要になる。
Playgroundを起動するだけでRailsサーバーが起動したり、実装が生成されたりするとは判断できない。
確認したソースはコンパイル結果をSwagger UIへ渡しており、Railsの起動や実装生成をAPIプレビューの前提処理として行っていない。[PlaygroundのSwagger UI連携](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/playground/src/react/viewers/react-wrapper.tsx)

このサンプルの操作画面をPlaygroundへ置き換えると、TypeSpec編集環境を配信するための依存とビルド構成が必要になる。
0.18.0の依存にはReact、Monaco、Fluent UI、TypeSpec bundlerが含まれる。
「APIの仕様を読んでExecuteする」という目的への適合は、追加される編集機能の必要性と合わせて判断する必要がある。[Playground 0.18.0の依存](https://registry.npmjs.org/@typespec%2fplayground/0.18.0)

公式ドキュメントと公式リポジトリの調査範囲では、Swagger UIを置き換える独立したTypeSpec専用のAPI操作UIは確認できなかった。
この結論は、第三者による実装が存在しないことまで保証しない。
確認できた公式の実装は、TypeSpecからOpenAPIを生成し、その表示にSwagger UIを使う。[公式OpenAPI紹介](https://typespec.io/openapi/)、[公式Playground](https://typespec.io/playground/)

## VS Code拡張の採用価値

仕様を編集する開発者には、公式VS Code拡張を追加する価値がある。
構文ハイライト、補完、formatter、live diagnostics、quick fix、rename、定義への移動を提供し、OpenAPI import、コード生成、APIドキュメントのプレビューにも対応する。[公式VS Codeドキュメント](https://typespec.io/docs/introduction/editor/vscode/)

Marketplaceの拡張IDは`typespec.typespec-vscode`で、調査時の配布版は1.17.0だった。
npmの`typespec-vscode`は1.13.0のままdeprecatedとなり、Marketplaceからの導入を案内している。
npm版の番号を拡張の最新版として扱うべきではない。[Marketplace](https://marketplace.visualstudio.com/items?itemName=typespec.typespec-vscode)、[npm 1.13.0のdeprecated情報](https://registry.npmjs.org/typespec-vscode/1.13.0)

プレビューの操作は、次のように案内できる。
これは公式ドキュメントとソースによる確認であり、この調査でVS CodeへのインストールやUI操作を実測したものではない。

1. VS CodeでMarketplaceの「TypeSpec」（`typespec.typespec-vscode`）を導入する。
2. このリポジトリを開き、依存が導入済みの状態で`api/main.tsp`を開く。
3. コマンドパレットから`TypeSpec: Preview API Documentation`を実行する。
4. 複数の`main.tsp`が見つかった場合は、対象を選択する。

コマンド名は公式ドキュメントに記載されている。
ソースでは対象のentrypointを探して一時ディレクトリへOpenAPIを生成し、Swagger UIのwebviewで表示する。[コマンド一覧](https://typespec.io/docs/introduction/editor/vscode/#commands)、[プレビュー実装](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/typespec-vscode/src/vscode-cmd/openapi3-preview.ts)、[Swagger UI initializer](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/typespec-vscode/swagger-ui/swagger-initializer.js)

このプレビューは仕様編集時の確認に適している。
Railsと同じoriginで動かすブラウザの操作画面とは実行環境が異なるため、現在のデモ画面を置き換える根拠にはならない。
API実行まで含む挙動は、このサンプルを対象に別途確認する必要がある。[VS Codeのwebviewでの読み込み実装](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/typespec-vscode/src/vscode-cmd/openapi3-preview.ts)

Visual Studio用の公式拡張もあり、Marketplace IDは`typespec.typespecvs`である。
このRailsサンプルの開発環境では、VS Code拡張のほうが直接の候補になる。[公式Visual Studioドキュメント](https://typespec.io/docs/introduction/editor/vs/)

## formatter、linter、再現可能な生成

TypeSpec compilerには、compile、format、init、installなどのCLIがある。
このリポジトリの1.17.0で`node_modules/.bin/tsp --help`を実行し、これらのコマンドとVS Code/Visual Studio拡張の管理コマンドを確認した。
formatはCI用の`--check`に対応し、VS Code/Visual Studio拡張やPrettierプラグインからも使える。[公式CLIガイド](https://typespec.io/docs/handbook/cli/)、[公式formatterガイド](https://typespec.io/docs/handbook/formatter/)

linterは、TypeSpecライブラリが用意した任意のルールを仕様へ適用する仕組みである。
たとえば`@typespec/http/all`は、HTTP関連のlinterルールを有効にする。
linterと実行時のrequest/response検証は入力も実行時点も異なり、linterだけでRailsのレスポンス違反を検出することはできない。[linterの仕組み](https://typespec.io/docs/extending-typespec/linters/)、[HTTP linter](https://typespec.io/docs/libraries/http/reference/linter/)

TypeSpecの公式ガイドは、`package-lock.json`の保存と`npm ci`による整合性確認を推奨している。
emitterの出力は、意味が等しい変更でもバージョン間で完全一致するとは限らない。
このサンプルのように版を固定し、生成結果の差分を確認する運用は、仕様からRailsへ渡る成果物を確認可能にする。[再現性のガイド](https://typespec.io/docs/handbook/reproducibility/)、[破壊的変更ポリシー](https://typespec.io/docs/handbook/breaking-change-policy/)

## 公式emitterの種類と成熟度

TypeSpec全体を一括して「preview」と分類するのは不正確である。
Microsoftの概要資料は、compiler、HTTP、OpenAPIのcoreとOpenAPI/JSON Schema emitterをGAまたはproduction-readyと説明している。
これらには1.17.0の配布版があり、1.0.0以上のパッケージを対象とする互換性ポリシーがある。[MicrosoftのTypeSpec概要](https://learn.microsoft.com/en-us/azure/developer/typespec/overview/)
ただし実験的APIは別扱いで、emitterの意味的に等しい出力変更もあり得る。[互換性ポリシー](https://typespec.io/docs/handbook/breaking-change-policy/)

| 分類 | パッケージ | 調査時のnpm `latest` | 機能を確認した資料 |
| --- | --- | --- | --- |
| 言語とコンパイル | `@typespec/compiler` | 1.17.0 | [配布版](https://registry.npmjs.org/@typespec%2fcompiler/1.17.0) |
| HTTP仕様 | `@typespec/http` | 1.17.0 | [配布版](https://registry.npmjs.org/@typespec%2fhttp/1.17.0) |
| OpenAPI出力 | `@typespec/openapi3` | 1.17.0 | OpenAPI 3.0、3.1、3.2を選択できる。[emitter options](https://typespec.io/docs/emitters/openapi3/reference/emitter/) |
| JSON Schema出力とimport | `@typespec/json-schema` | 1.17.0 | [README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/json-schema/README.md)、[配布版](https://registry.npmjs.org/@typespec%2fjson-schema/1.17.0) |
| Protobuf/gRPC出力 | `@typespec/protobuf` | 0.87.0 | [README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/protobuf/README.md)、[配布版](https://registry.npmjs.org/@typespec%2fprotobuf/0.87.0) |
| GraphQL出力 | `@typespec/graphql` | 0.4.0 | [README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/graphql/README.md)、[配布版](https://registry.npmjs.org/@typespec%2fgraphql/0.4.0) |
| 共通REST仕様 | `@typespec/rest` | 0.87.0 | [配布版](https://registry.npmjs.org/@typespec%2frest/0.87.0) |
| APIのversioning | `@typespec/versioning` | 0.87.0 | [配布版](https://registry.npmjs.org/@typespec%2fversioning/0.87.0) |
| 独自emitterの作成 | `@typespec/emitter-framework` | 0.21.0 | 公式ガイドはexperimentalと明記。[emitter framework](https://typespec.io/docs/extending-typespec/emitter-framework/)、[配布版](https://registry.npmjs.org/@typespec%2femitter-framework/0.21.0) |

0.xであることだけで、各パッケージの品質や用途を一律に判断することはできない。
この表は配布版と機能の確認資料を示したもので、各ライブラリの成熟度を網羅したものではない。
Protobuf、GraphQL、REST、versioningは、現在の公式docsのsidebarではpreview表記である。[公式docs](https://typespec.io/docs/)
client/serverの生成器については、次の表で資料上の状態と配布版を分けて示す。

### clientを直接生成するemitter

公式client一覧にはJavaScript/TypeScript、Python、Java、C#の4種類がある。
現在の公式docsのsidebarと一覧ガイドはpreviewと記載しているが、インストール例には旧版が含まれる。
個別のREADME、参照ドキュメント、配布版メタデータも確認し、GAへの移行を示す一次資料は今回の範囲では確認できなかった。[公式client一覧](https://typespec.io/docs/emitters/clients/introduction/)、[JavaScript/TypeScriptの個別資料](https://typespec.io/docs/emitters/clients/http-client-js/reference/)

| 生成先 | パッケージ | 調査時のnpm `latest` | 状態の確認 |
| --- | --- | --- | --- |
| JavaScript/TypeScript | `@typespec/http-client-js` | 0.16.3（2026-10-08公開） | 一覧ではpreview。個別READMEにGAの明記なし。[README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/http-client-js/README.md)、[配布版](https://registry.npmjs.org/@typespec%2fhttp-client-js/0.16.3) |
| Python | `@typespec/http-client-python` | 0.38.1（2026-10-08公開） | 一覧ではpreview。個別READMEにGAの明記なし。[README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/http-client-python/README.md)、[配布版](https://registry.npmjs.org/@typespec%2fhttp-client-python/0.38.1) |
| Java | `@typespec/http-client-java` | 0.9.0（2026-06-11公開） | 一覧ではpreview。個別READMEにGAの明記なし。[README](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/http-client-java/README.md)、[配布版](https://registry.npmjs.org/@typespec%2fhttp-client-java/0.9.0) |
| C# | `@typespec/http-client-csharp` | 1.0.0-alpha.20261008.5（2026-10-08 UTC公開） | 一覧ではpreview。現在の配布版自体がalpha。[配布版](https://registry.npmjs.org/@typespec%2fhttp-client-csharp/1.0.0-alpha.20261008.5) |

C#の`1.0.0-alpha...`は、安定版1.0.0として扱えない。
この表は直接生成の存在と配布状態を確認したもので、生成物のコンパイルやRailsサンプルとの通信を実測したものではない。

### serverを直接生成するemitter

公式server emitterでは、C#とJavaScript/TypeScriptを確認した。
どちらの公式プロジェクト説明もhighly experimentalと明記し、現在の配布版にもalphaが付いている。[C# server](https://typespec.io/docs/emitters/servers/http-server-csharp/project/)、[JavaScript server](https://typespec.io/docs/emitters/servers/http-server-js/project/)

| 生成先 | パッケージ | 調査時のnpm `latest` | 生成するもの |
| --- | --- | --- | --- |
| C#/ASP.NET Core | `@typespec/http-server-csharp` | 0.58.0-alpha.33（2026-10-08公開） | MVC controller、モデル、業務実装用interface。[公式説明](https://typespec.io/docs/emitters/servers/http-server-csharp/project/)、[配布版](https://registry.npmjs.org/@typespec%2fhttp-server-csharp/0.58.0-alpha.33) |
| JavaScript/TypeScript/Node.js | `@typespec/http-server-js` | 0.58.0-alpha.29（2026-09-09公開） | TypeScript interface、HTTP router、Express middlewareなど。[公式説明](https://typespec.io/docs/emitters/servers/http-server-js/project/)、[配布版](https://registry.npmjs.org/@typespec%2fhttp-server-js/0.58.0-alpha.29) |

公式の資料と`microsoft/typespec`のpackages一覧では、Ruby/Rails用の直接client/server emitterは確認できなかった。
Java用clientは存在するが、公式Java server emitterも確認できなかった。[公式packages一覧](https://github.com/microsoft/typespec/tree/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages)、[公式client一覧](https://typespec.io/docs/emitters/clients/introduction/)

### OpenAPI Generator経由のRuby/Rails生成

生成OpenAPIからRuby/Railsコードを作る方法は、OpenAPIエコシステム側にある。
OpenAPI Generatorには、`ruby-on-rails`、`ruby-sinatra`、`ruby`のgeneratorがあり、いずれも公式の成熟度欄はSTABLEである。
前二者はserver用、`ruby`はclient SDK用である。[Rails generator](https://openapi-generator.tech/docs/generators/ruby-on-rails/)、[Sinatra generator](https://openapi-generator.tech/docs/generators/ruby-sinatra/)、[Ruby client generator](https://openapi-generator.tech/docs/generators/ruby/)

ただし`ruby-on-rails`の公式説明はRails v5を対象としており、Rails 8.1への適合を確認する根拠にはならない。
OpenAPI Generator全体のREADMEも、OpenAPI 3.1をbeta supportと記載している。
調査時の最新stableは7.26.0（2026-10-06）だった。[Rails generatorの説明](https://openapi-generator.tech/docs/generators/ruby-on-rails/)、[公式READMEの対応範囲](https://github.com/OpenAPITools/openapi-generator#11---compatibility)

上記3種類のfeature matrixでは、`Null`、`Union`、`allOf`、`anyOf`、`oneOf`、`not`が未対応の表記になっている。
Rails/Sinatraのsecurityも未対応の表記である。
STABLEというラベルから、OpenAPI 3.1の全機能への対応を推定することはできない。[Railsのfeature matrix](https://openapi-generator.tech/docs/generators/ruby-on-rails/)、[Sinatraのfeature matrix](https://openapi-generator.tech/docs/generators/ruby-sinatra/)、[Ruby clientのfeature matrix](https://openapi-generator.tech/docs/generators/ruby/)

コード生成と、動いているRailsアプリの契約検証には、別の処理が必要になる。
OpenAPI Generatorの`validate`は入力OpenAPI文書を検証するコマンドであり、Railsの実request/responseを照合するコマンドではない。
このサンプルの`openapi_first`とRSpecを生成器へ置き換える判断はできない。[公式CLIのvalidate説明](https://openapi-generator.tech/docs/usage/#validate)

## AI向けの公式MCPプロジェクト

Microsoftの別リポジトリ`typespec-mcp`には、TypeSpecでMCP serverを定義して生成する試みもある。
READMEはPublic Previewと記載し、仕様の学習、init、compile、buildをAIから使うauthoring serverと、MCP toolやremote REST呼び出しのserver生成器を紹介している。
API操作UIやRailsの契約validatorを提供するものではない。[公式README](https://github.com/microsoft/typespec-mcp)

このリポジトリは、調査時点でarchivedだった。
authoring serverのnpm latestは`mcp-server-typespec` 0.0.0-104（2025-10-06公開）、REST bridgeは`typespec-mcp-http-server-js` 0.0.0-0（2025-05-12公開）である。
このライフサイクルと用途から、今回のサンプルへ追加する候補には選ばない。[公式GitHubの状態](https://api.github.com/repos/microsoft/typespec-mcp)、[authoring serverのregistry](https://registry.npmjs.org/mcp-server-typespec)、[REST bridgeのregistry](https://registry.npmjs.org/typespec-mcp-http-server-js)

## 公式コミュニティと開発予定

公式コミュニティページは、GitHub、contribution、Discordを案内している。
このページには、第三者ツールを網羅するカタログは掲載されていない。
公式のサポート範囲を確かめるには、docsの各emitterと公式packagesを照合する必要がある。[公式コミュニティページ](https://typespec.io/community/)、[公式packages](https://github.com/microsoft/typespec/tree/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages)

公式リポジトリのmilestonesには、調査時点で2026年11月、12月、2027年1月の予定がある。
10月milestoneにはPlayground、OpenAPI、C# server、compilerなどの未完了項目も残っている。
予定やissueの存在は、機能が提供済みであることや、提供時期を保証する根拠には使わない。[公式milestones](https://github.com/microsoft/typespec/milestones)、[2026年10月](https://github.com/microsoft/typespec/milestone/58)、[2026年11月](https://github.com/microsoft/typespec/milestone/59)

## このサンプルで追加調査したUI

このサンプルでは、OpenAPI 3.1を読めること、ブラウザから実Rails APIへ送信できること、ローカルassetsで配信できることを比較の前提にした。
仕様が定める制約の読み取りやすさと、Rails側の契約違反を確かめる操作も評価対象にする。
TypeSpec対応という表示だけでは、これらの用途への適合は判断できない。
ブラウザで実測したのはSwagger UIとScalarであり、その他の候補は公式資料による比較である。

| UIと調査時の版 | ライセンス | 実APIの操作 | 導入形態とこのサンプルでの判断 | 主な一次資料 |
| --- | --- | --- | --- | --- |
| Swagger UI 5.33.1 | Apache-2.0 | Try it out/Execute | 現行のローカルassetsと同一origin配信。TypeSpec公式のプレビューにも採用されており、基準とする | [設定ガイド](https://swagger.io/docs/open-source-tools/swagger-ui/usage/configuration/)、[対応表](https://github.com/swagger-api/swagger-ui#compatibility)、[配布版](https://registry.npmjs.org/swagger-ui-dist/5.33.1) |
| Scalar API Reference 1.73.1 | MIT | API clientによる送信 | standalone JSをローカル配信できる。最優先の比較候補として、同じ契約で実測した | [OpenAPI対応](https://scalar.com/products/api-references/openapi)、[設定ガイド](https://scalar.com/products/api-references/configuration)、[base server URLの公式E2E](https://github.com/scalar/scalar/blob/main/packages/api-reference/test/configuration/base-server-url.e2e.ts)、[配布版](https://registry.npmjs.org/@scalar%2fapi-reference/1.73.1) |
| RapiDoc 10.1.0 | MIT | Try機能 | 単一JSのweb componentとして導入できる軽量候補。今回の最優先比較はScalarとした | [OpenAPI対応](https://github.com/rapi-doc/RapiDoc/blob/master/docs/src/content/docs/get-started/openapi-support.mdx)、[配布版](https://registry.npmjs.org/rapidoc/10.1.0) |
| Stoplight Elements 9.0.27 | Apache-2.0 | Try it機能 | JS/CSSと`elements-api`をHTML1枚へ組み込める。今回の最優先実測はScalarとしたため、Elementsの表示と操作は未実測 | [HTML導入ガイド](https://github.com/stoplightio/elements/blob/main/docs/getting-started/elements/html.md)、[配布版](https://registry.npmjs.org/@stoplight%2felements/9.0.27) |
| OpenAPI Explorer 2.4.820 | Apache-2.0 | API送信 | この用途に適合する候補だが、既存Swagger UIから移行する決定的な利点は今回確認できなかった | [公式変更履歴](https://github.com/Authress-Engineering/openapi-explorer/blob/release/2.4/CHANGELOG.md)、[配布版](https://registry.npmjs.org/openapi-explorer/2.4.820) |
| Redoc Community Edition 2.5.4 | MIT | CEにはTry it機能なし | 閲覧中心の文書に適する。hosted製品とは機能を区別し、今回のAPI操作画面の代替には選ばない | [CEとhostedの差](https://github.com/Redocly/redoc#redoc-vs-hosted-redoc)、[配布版](https://registry.npmjs.org/redoc/2.5.4) |
| Zudoku 0.92.0 | MIT | API playground | 文書portalとしてbuild構成を持つ。このサンプルの薄いhostを置き換えるには追加構成が大きい | [公式リポジトリ](https://github.com/zuplo/zudoku)、[配布版](https://registry.npmjs.org/zudoku/0.92.0)、[版を固定したLICENSE](https://github.com/zuplo/zudoku/blob/v0.92.0/LICENSE.md) |

OpenAPI 3.1への対応表記と、JSON Schema 2020-12の各keywordを画面に表示することは、別々に確認する必要がある。
たとえばSwagger UIには`unevaluatedProperties`専用のrendererがある。
Scalarは調査したSchemaObjectPropertiesに専用表示が見当たらなかったが、bundle内にはkeywordも含まれるため、これだけで非対応とは断定しない。[Swagger UIの専用renderer](https://github.com/swagger-api/swagger-ui/blob/master/src/core/plugins/json-schema-2020-12/components/keywords/UnevaluatedProperties.jsx)、[Scalarのproperties表示](https://github.com/scalar/scalar/blob/main/packages/blocks/src/schema/SchemaObjectProperties.vue)

### 同じ契約での実測

Scalar 1.73.1のstandaloneとSwagger UI 5.33.1をローカル配信し、同じ生成OpenAPIと比較用Rails API（`http://127.0.0.1:3004`）で操作を確認した。
Scalarには、既定fontを無効化する`withDefaultFonts: false`、`agent: { disabled: true }`、`showDeveloperTools: "never"`、`telemetry: false`を指定し、proxyは設定しなかった。
ブラウザで外部originへの通信を遮断した条件でも、両UIで次の7ケースが期待どおりのHTTP statusになった。
設定項目の定義は公式ガイドによるが、表の結果はこのサンプルでの実測である。[Scalarの設定ガイド](https://scalar.com/products/api-references/configuration)

| 操作 | Scalar | Swagger UI | 確認した内容 |
| --- | --- | --- | --- |
| `POST /api/tasks`へ有効なtitleを送信 | 201 | 201 | タスクを作成できた |
| `POST /api/tasks`へ`{}`を送信 | 400 | 400 | 必須titleの不足をRails側で拒否した |
| `POST /api/tasks`へ未定義プロパティを含む入力を送信 | 400 | 400 | 追加プロパティをRails側で拒否した |
| `GET /api/tasks` | 200 | 200 | Scalarだけ`status=todo`を指定し、Swagger UIはqueryなしで一覧を取得した |
| `GET /api/tasks/{id}` | 200 | 200 | Scalarはid 1、Swagger UIはid 2を取得できた |
| `PATCH /api/tasks/{id}`でtitleと`status: done`を更新 | 200 | 200 | 返却内容と保存結果を確認した |
| `PATCH /api/tasks/{id}`へ`status: paused`を送信 | 400 | 400 | enum違反をRails側で拒否した |

PATCH後の保存結果は、比較用DBをread-onlyのRails runnerで読み、id 1とid 2それぞれの更新後titleと`status: done`を確認した。

Scalarの実際のfetch URLは、正しく`http://127.0.0.1:3004/api/tasks`以下になっていた。
ScalarのSendボタンの表示には`//api`が現れたが、実際の送信では単一の`/`であり、通信の障害とは扱わない。
両UIともpageerrorは発生せず、Swagger UIでは外部originへのrequestも0件だった。
Scalarは、viewportを390pxにした場合のdocument scrollWidthも390pxだった。
これらは今回の操作と表示幅を対象とする結果であり、認証やすべての端末を確認したものではない。

モデル表示には、このデモの目的に関係する差があった。
Swagger UIでTaskモデルを展開すると、requiredの3項目、titleの長さ1〜100、statusのenumに加え、`Unevaluated properties never`が表示された。
Scalarで同じTaskモデルを展開すると、requiredの3項目、titleのmin 1/max 100、enumの3値は確認できたが、その展開画面では追加プロパティ禁止の表示を見つけられなかった。
この観測から、Scalar全体が`unevaluatedProperties`に非対応だとは一般化しない。
未知のプロパティを送った実測でも400を返しており、実際の入力検証はRails側が担っている。

Scalarのこの構成では、CreateTaskの自動提示request exampleのtitleが空文字になり、`minLength: 1`を満たさない表示を観測した。
有効なtitleを手動入力すれば201になる。
追加プロパティ禁止を画面から読み取ることと、初期の例からAPIを試すことは、この小さな契約検証デモの操作性に関係する。
この表示差を、移行に伴う構成変更と合わせて評価し、今回はSwagger UIを維持する判断とした。

比較後はブラウザの比較タブを閉じ、比較用サーバーを停止した。
実測のために元のアプリや依存を変更していない。
このリポジトリでは、任意の公式VS Code拡張とPlaygroundの案内をREADMEへ追加する構成とした。

## API操作UIと混同しやすい補完ツール

公式には、型構造を調べる`html-program-viewer`、TypeSpecライブラリの文書を作る`tspd`、HTTPテスト用のSpectorもある。
役割は異なるため、これらの存在から「TypeSpec専用のSwagger UI代替がある」と判断することはできない。

| ツール | 確認した役割 | 今回の採否を分ける点 |
| --- | --- | --- |
| `@typespec/html-program-viewer` | コンパイルした型構造をHTMLで調べる | API操作画面としては採用しない。[公式パッケージ](https://github.com/microsoft/typespec/tree/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/html-program-viewer) |
| `tspd` | TypeSpecライブラリの型、decorator、emitter optionsなどを文書化する実験的ツール | Rails APIのHTTP操作画面とは用途が異なる。[公式パッケージ](https://github.com/microsoft/typespec/tree/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/tspd) |
| Spector | mock APIと期待値を定義してテストする。`server-test`/`knock`で実サーバーにも送信できる | 独自の期待値が必要となり、このサンプルのTypeSpecから生成したOpenAPIを直接判定基準とするRails側の検証を、そのまま置き換えるものではない。[利用ガイド](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/spector/docs/using-spector.md)、[期待値の定義](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/spector/docs/writing-mock-apis.md)、[server-test](https://github.com/microsoft/typespec/blob/62f1d298cac7ee3360ec0f6ba84f2bf1e299dba0/packages/spector/src/actions/server-test.ts) |
| `typespec-openapi-document` 0.5.0 | 既存openapi3 JSONをimportする`document.gen.ts`を生成する第三者emitter | HTML、UI assets、Rails実装は生成しない。Swagger UI/Scalarのadapterは利用側に追加するため、UI導入を自動化する代替には選ばない。[emitter](https://github.com/bison-digital/typespec-openapi-document/blob/92c688d0ad8e483c1f35e410eb4edbbf15162ea1/src/emitter.ts)、[出力](https://github.com/bison-digital/typespec-openapi-document/blob/92c688d0ad8e483c1f35e410eb4edbbf15162ea1/src/render.ts)、[配布版](https://registry.npmjs.org/typespec-openapi-document/0.5.0) |
