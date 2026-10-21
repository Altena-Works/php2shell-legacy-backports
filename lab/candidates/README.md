# 未検証の作業候補

`php-7.3.33-session-preserving.patch` は、PHP 7.3.33 の元アーカイブに対し既存の緊急変更と upload progress の機能維持案を合わせた**開発途中の差分**です。fuzz なしの dry-run 適用のみ確認済みです。ビルド、Apache/mod_php の実行、保存済みセッション形式の互換性、2 件の CVE の遮断は未検証です。導入用には `patches/` の版別パッチを使い、この候補を配布済みの修正として扱わないでください。

`checks/7.3.33.sh` は候補専用の正常系確認です。通常のmultipart/upload progressと、既存セッション内の無害な`Serializable`値が更新後も読めることを確認します。脆弱性の遮断を証明するテストではありません。`lab/run-matrix.sh` の `--patch-dir` / `--check-dir` には、この候補をそれぞれ `php-7.3.33.patch` / `7.3.33.sh` として配置した一時ディレクトリを渡します。既存の検証結果と混ざらない新しい `--results-dir` を指定してください。
