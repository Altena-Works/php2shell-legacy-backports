# PHP 8.0.30 緊急パッチの検証記録

確認日：2026-10-22（日本時間）。対象は `patches/php-8.0.30.patch` と、配布元の `php-8.0.30.tar.gz`。パッチは PHP 公式の旧版向け最小バックポートに対応し、`session.upload_progress` を停止する。

- 元ソース SHA-256：`449d2048fcb20a314d8c218097c6d1047a9f1c5bb72aa54d5d3eba0a27a4c80c`
- パッチ SHA-256：`534478c973cef6f493605b7af907f639a364912ee92c24598ddae44c3bc72d1c`
- ビルドした `libs/libphp.so` SHA-256：`d82757cc365ddc4cebf596e6cec077a696d05f88dd671013c6060f68ba640600`

`lab/run-matrix.sh` の fuzz なし適用、ソース検査、ビルド、Apache モジュールのファイル一致、HTTP 応答は `pass`。応答は `8.0.30 / apache2handler / SESSION_OK`。別の通常 multipart 投稿では `$_POST` と `$_FILES` を確認し、`MULTIPART_OK` を得た。テストは外部ポートを開かない `linux/amd64` コンテナで実施した。

追加の良性検査では `session.upload_progress.enabled=On`、`cleanup=Off` として投稿し、`MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT` を確認した。

これらは通常機能の回帰確認であり、両 CVE の悪用不能性を実証しない。PHP-FPM、LSAPI、配布元独自ビルド、ネイティブ x86_64 の競合タイミングは未検証。
