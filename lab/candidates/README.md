# 未検証の作業候補

7.3.33 の統合候補には、遅延 OOM 中断、主要文字列関数の失敗可能な割当、`explode` と upload progress の OOM 保留確認を含めました。直前の差分ではセッション復号・読込・GC 中の保留 OOM 時に追加処理を止め、固定済み元アーカイブからクリーンビルドして Apache/mod_php 版別チェックを通過しました。現行差分では保存モジュールの open・ID生成・read の失敗分岐を守り、multipart 終了時には配列分離・更新後に `bytes_processed` バケットを引き直します。パッチ SHA-256 は `8e22b13a260f51f9295c585a1483677abaf78832259b978deeeccae89af8652b`。元ソースへの fuzz なし dry-run、Linux/amd64 の増分ビルド、3 種類のセッション保存形式を含む版別チェックを通過し、生成した `libphp7.so` は `b92f00230db4e083259b450af5e4ec6b9a939f50efb519be370fdba5ed1a8135` です。大きな通常セッションを使った良性 multipart では、メモリ上限エラー後も同じワーカーが継続し、アプリのスクリプトは実行されませんでした。配列分離後のポインタ更新箇所を直接狙った検査、OOM の厳密な発生地点、現行差分全体の再クリーンビルド、他の大型割当・再割当・両 CVE の全経路遮断は未確認です。

`patches/php-5.6.40.patch` は 5.6.40 機能維持候補を並列検証用に単一化した差分です。固定済み公式アーカイブから `lab/run-matrix.sh` で fuzz なし適用・クリーンビルドし、Apache/mod_php の通常セッション・multipart・進捗、3 種類の保存形式、参照値、ファイルなし投稿を確認しました。その後、割当上限の桁あふれ防止を追加して fuzz なし dry-run、増分ビルドと同じ正常系を再確認しました。現行候補の SHA-256 は `f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f` です。追加変更後のクリーンビルド、両 CVE の全経路遮断と soft OOM 後の同一ワーカー継続は未確認です。配布用 `patches/` へは昇格していません。

`php-5.6.40-late-error.patch` は、既存の緊急差分に、post-RSHUTDOWN 後の `last_error_message`・`last_error_file` 消去を加えた合成差分です。PHP 5.6.40 の元アーカイブへ fuzz なしで適用し、Linux/amd64・Apache/mod_php でクリーンビルド、通常セッション・multipart、進捗停止を確認しました。後処理診断による残存状態と両 CVE の全経路は未検証です。配布用 `patches/` には移していません。

`php-5.6.40-session-preserving.patch` は、上記の緊急差分を土台に、早期の upload progress 更新中だけ保存済みオブジェクトを不完全クラスとして復号し、`Serializable` の元ペイロードを再保存する**開発途中の差分**です。multipart 開始時にセッション状態を初期化し、保存先の初期化・読取失敗時は進捗更新を止めます。既存の進捗キーが参照値なら、旧版のシンボル更新が値を移した先へ進捗側の `zval *` を付け替え、旧版の参照関係も保ちます。通常の `serialize()` と通常のセッション読取失敗の扱いは維持します。元アーカイブへの fuzz なし適用、Linux/amd64・Apache/mod_php のクリーンビルド後の増分コンパイル、通常の multipart・upload progress、無害な `Serializable` 値の維持を確認しました。[早期失敗検査](check-session-init-failure.sh)では無効な保存先で警告が記録され、通常のアップロードと同じワーカーの後続要求が成功しました。[参照値検査](check-reference-progress.sh)では進捗と別キーの参照関係を確認しました。[保存形式検査](check-session-formats.sh)では `php`・`php_binary`・`php_serialize` で無害な `Serializable` 値、通常 multipart、進捗記録を確認しました。両 CVE の遮断、OOM 後のワーカー回復、保存形式の異常系や他のデータ型は未検証です。配布用 `patches/` には移していません。

ファイルなし multipart の終了時に未作成の進捗データを更新しない条件を追加しました。[回帰検査](check-no-file-progress.sh)では修正前の接続断、修正後の通常投稿・既存セッション維持を確認し、ファイルありの進捗記録も再確認しました。全入口の遮断判定ではありません。

公式 8.2.35 の早期 RINIT 境界に合わせ、通常のモジュール RINIT より前に basic のシリアライズ状態と URL リライター状態をリセットします。元ソースへの fuzz なし適用、Linux/amd64・Apache/mod_php の増分ビルド、3種類のセッション保存形式での通常投稿・進捗・既存値維持、ファイルなし投稿を確認しました。前リクエストの異常終了状態を人工的に作る検査や全経路遮断の判定は未実施です。

`php-7.3.33-session-preserving.patch` は、PHP 7.3.33 の元アーカイブに対し既存の緊急変更と upload progress の機能維持案を合わせた**開発途中の差分**です。fuzz なしの適用、Linux/amd64・Apache/mod_php のビルドと起動、通常の multipart・upload progress、無害な `Serializable` 値のセッション維持を確認しました。確認したのはこの正常系のみです。保存済みセッション形式全般の互換性、OOM 後の挙動、2 件の CVE の遮断は未検証です。導入用には `patches/` の版別パッチを使い、この候補を配布済みの修正として扱わないでください。

同候補に、公式 8.2.35 の basic/URL リライター早期要求リセットを移植しました。固定済み公式アーカイブから展開した元ソースへ fuzz なしで適用でき、続く遅延 OOM 実験差分も fuzz なしで適用できます。Linux/amd64・Apache/mod_php の増分ビルド、通常セッション・multipart・進捗と無害な `Serializable` 値の維持を確認しました。異常終了後の残存状態を動的に再現した検査ではありません。

`php-7.3.33-delayed-oom.experimental.patch` は統合前の旧実験差分です。現在の統合候補には遅延 OOM、JSON 中断、`str_repeat`・`str_pad`・`implode`・`chunk_split`・`wordwrap` 用の失敗可能割当が含まれるため、この旧差分を重ねません。**2件の CVE の全入口・例外経路、他の設定や保存形式の互換性は未検証です。配布・導入用パッチではありません。**

統合した実験用の単一差分は [patches/php-7.3.33.patch](patches/php-7.3.33.patch) です。固定済み公式アーカイブから `lab/run-matrix.sh` で fuzz なし適用・クリーンビルドを行い、Apache/mod_php の通常セッション・multipart・進捗・`Serializable` 値維持を確認しました。同じビルドで良性の通常 soft OOM と配列復号中の soft OOM が報告され、同じワーカーが次要求を処理しました。**この結果は両 CVE の完全遮断を示さず、`patches/` の配布用差分へ昇格していません。**

`checks/5.6.40.sh` と `checks/7.3.33.sh` は候補専用の正常系確認です。通常の multipart/upload progress と、既存セッション内の無害な `Serializable` 値が更新後も読めることを確認します。脆弱性の遮断を証明するテストではありません。`lab/run-matrix.sh` の `--patch-dir` / `--check-dir` には、候補を版名に合わせて配置した一時ディレクトリを渡します。チェックはリポジトリ内の良性フィクスチャを読むため、一時ディレクトリへはコピーせずシンボリックリンクで配置します。既存の検証結果と混ざらない新しい `--results-dir` を指定してください。

7.3.33 の版別確認では、通常の multipart 終了後に進捗の `done=true` と `bytes_processed=content_length` も確かめます。Linux/amd64・Apache/mod_php で通過しました。これは最終進捗の正常動作を示す検査であり、OOM や異常終了時の両 CVE の遮断証明ではありません。8.2.34→8.2.35 の `ext/standard/array.c` 差分にある配列割当の失敗可能処理は、現候補には未移植です。

2026-10-22 の追加差分では、公式 8.2.35 と同じ終了境界で、post-RSHUTDOWN 後に再設定され得る `last_error_message` と `last_error_file` をメモリ管理終了前に消去します。変更した `main/main.c` は既存の Linux/amd64 ビルド木で増分コンパイルし、上記の正常系を再実行して通過しました。後処理中の診断を動的に起こした確認や、CVE-2026-109619 の全入口の遮断確認は未実施です。
