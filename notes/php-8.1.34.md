# PHP 8.1.34 緊急パッチの検証記録

確認日：2026-10-22（日本時間）。対象は `patches/php-8.1.34.patch` と、配布元の `php-8.1.34.tar.gz`。パッチは PHP 公式の旧版向け最小バックポートに対応し、`session.upload_progress` を停止する。

- 元ソース SHA-256：`3c5b060ec8e0d5dd1d8237823f3161cc8bc5342aab3c46893eba9857759c4bfa`
- パッチ SHA-256：`c85ad0fddcbff7f2318617eeaa54d271135463b5bf70a01228447e3ed78de96e`
- ビルドした `libs/libphp.so` SHA-256：`14dd3fff9da296b8ccb5eb0c38f764f223a8deb19206a85eb0c14c36b72e9868`

`lab/run-matrix.sh` の fuzz なし適用、ソース検査、ビルド、Apache モジュールのファイル一致、HTTP 応答は `pass`。応答は `8.1.34 / apache2handler / SESSION_OK`。別の通常 multipart 投稿では `$_POST` と `$_FILES` を確認し、`MULTIPART_OK` を得た。テストは外部ポートを開かない `linux/amd64` コンテナで実施した。

これらは通常機能の回帰確認であり、両 CVE の悪用不能性を実証しない。PHP-FPM、LSAPI、配布元独自ビルド、ネイティブ x86_64 の競合タイミングは未検証。
