# 未検証の作業候補

`php-5.6.40-late-error.patch` は、既存の緊急差分に、post-RSHUTDOWN 後の `last_error_message`・`last_error_file` 消去を加えた合成差分です。PHP 5.6.40 の元アーカイブへ fuzz なしで適用し、Linux/amd64・Apache/mod_php でクリーンビルド、通常セッション・multipart、進捗停止を確認しました。後処理診断による残存状態と両 CVE の全経路は未検証です。配布用 `patches/` には移していません。

`php-5.6.40-session-preserving.patch` は、上記の緊急差分を土台に、早期の upload progress 更新中だけ保存済みオブジェクトを不完全クラスとして復号し、`Serializable` の元ペイロードを再保存する**開発途中の差分**です。通常の `serialize()` はこの専用モードを使いません。元アーカイブへの fuzz なし適用、Linux/amd64・Apache/mod_php のクリーンビルド、通常の multipart・upload progress、無害な `Serializable` 値の更新後の維持を確認しました。ビルド時に生成された復号器を候補内の生成済み C へ戻して再コンパイルし、同じ良性検査を再実行しました。両 CVE の遮断、OOM 後のワーカー回復、保存形式全般の互換性は未検証です。配布用 `patches/` には移していません。

`php-7.3.33-session-preserving.patch` は、PHP 7.3.33 の元アーカイブに対し既存の緊急変更と upload progress の機能維持案を合わせた**開発途中の差分**です。fuzz なしの適用、Linux/amd64・Apache/mod_php のビルドと起動、通常の multipart・upload progress、無害な `Serializable` 値のセッション維持を確認しました。確認したのはこの正常系のみです。保存済みセッション形式全般の互換性、OOM 後の挙動、2 件の CVE の遮断は未検証です。導入用には `patches/` の版別パッチを使い、この候補を配布済みの修正として扱わないでください。

`checks/5.6.40.sh` と `checks/7.3.33.sh` は候補専用の正常系確認です。通常の multipart/upload progress と、既存セッション内の無害な `Serializable` 値が更新後も読めることを確認します。脆弱性の遮断を証明するテストではありません。`lab/run-matrix.sh` の `--patch-dir` / `--check-dir` には、候補を版名に合わせて配置した一時ディレクトリを渡します。チェックはリポジトリ内の良性フィクスチャを読むため、一時ディレクトリへはコピーせずシンボリックリンクで配置します。既存の検証結果と混ざらない新しい `--results-dir` を指定してください。

2026-10-22 の追加差分では、公式 8.2.35 と同じ終了境界で、post-RSHUTDOWN 後に再設定され得る `last_error_message` と `last_error_file` をメモリ管理終了前に消去します。変更した `main/main.c` は既存の Linux/amd64 ビルド木で増分コンパイルし、上記の正常系を再実行して通過しました。後処理中の診断を動的に起こした確認や、CVE-2026-109619 の全入口の遮断確認は未実施です。
