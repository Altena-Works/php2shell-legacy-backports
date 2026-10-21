# PHP 5.6.40 緊急候補の状態

元ソースは PHP 公式配布の `php-5.6.40.tar.gz`（SHA-256 `56fb9878d12fdd921f6a0897e919f4e980d930160e154cbde2cc6d9206a27cac`）。`ext/session/session.c` の照合値は `ae7286b24e1417ed2cef2e59d94525d5fe293cfb7cebc3be383800df78f621b6`。

## CVE-2026-109618

PHP 5.6.40 の `Zend/zend_alloc.c` は OOM 時に `zend_mm_safe_error()` から `zend_bailout()` を呼ぶ。Apache/mod_php はリクエスト開始が失敗しても終了処理へ進む。この組み合わせは [PHP 公式の説明](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)にある危険な状態遷移と一致する。

`patches/php-5.6.40.patch`（SHA-256 `538e8b0543607bf15227697b6473938dbf4cfde8a0781ed604e308e8777c9899`）は、[PHP 公式の 7.4 向け最小バックポート](https://github.com/php/php-src/tree/PHP-7.4-CVE-2026-109618-109619)と同じ安全側の方法で、OOM と関連する割当サイズのオーバーフロー時にワーカーを即時終了させる。`zend_strtod.c` の `Balloc()` での割当失敗も含む。通常の割当経路は変更しない。OOM 時に PHP の通常のエラーハンドラやシャットダウン処理が動かなくなる挙動変更がある。最終候補は元ソースからの fuzz なし適用・クリーンビルドを通り、隔離 Linux/amd64・Apache/mod_php で通常セッション HTTP を確認した。制御された OOM 後のワーカー回復は未確認。

2026-10-22 の追加照合では、元アーカイブのハッシュ確認、fuzz なしの適用、修正後の対象 7 ファイルの SHA-256 照合、既存の静的安全条件、Apache/mod_php の通常動作、良性 multipart 投稿を確認した。`checks/5.6.40.sh` は対象ファイルの一致を確認した後も、別経路が未調査のため終了コード 3 を保つ。これは公式最小バックポートで用いた**検証項目**へ近づけるものであり、同等の防御範囲を立証するものではない。

同じラボ構成で元ソースから無修正版を再ビルドした。無修正版は `baseline pass`、修正候補は既知の未完了判定による `fail (3)` で、どちらも `5.6.40 / apache2handler / SESSION_OK` を返した。良性 multipart 検査は無修正版が `MULTIPART_OK / SESSION_OK / PROGRESS_PRESENT`、修正候補が `MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT`。ビルドした `libphp5.so` の SHA-256 は無修正版 `c3b5a44ec30bb84b085a42453ead4ff356aca41859f42ca0f19079965e1a054e`、修正候補 `40090cd73b758fbdf58ebbb82a6aa0a86fe6e8427ded9f49fa13dd1fb5bb1d58`。

## CVE-2026-109619

**緊急緩和を追加したが、完全遮断は未検証。** PHP 5.6.40 の upload progress カウンタは独立して確保した `zval *` であり、8.x の HashTable bucket ポインタと同じ実装ではない。また、5.6 の `last_error` の文字列は `strdup` / `free` で管理される。これらの相違だけで安全とは判定できない。リクエストをまたいで残る session、executor、SAPI、拡張状態について、具体的な producer / consumer と正常動作への影響を調べる必要がある。

さらに、5.6 の session decoder は `PHP_VAR_UNSERIALIZE_INIT` を使い、unserializer は `__wakeup` や設定された callback を呼び得る。8.2.35 は upload progress 中にのみ不完全クラスとして扱うための専用モードを追加したが、5.6 に対応 API はない。機能を維持して同じ境界を作るには unserializer を含む移植が要る。

5.6 の候補経路として、アップロード中の `php_session_initialize()` は `php_session_track_init()` で `PS(http_session_vars)` を公開してから session の読取・復号を行う。復号時の callback や fatal interruption により対応する終了処理が飛ぶ可能性がある。次のリクエストで通常の RINIT より先に動く upload progress と INI 診断は、[公式 advisory](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)が示す早期 consumer である。5.6 の `zend_error()` は入口で `EG(exception)` を読み、従来の `shutdown_executor()` はその値を最後に必ず消す実装ではなかった。ただし、5.6 でこれらが組み合わさる具体的な悪用条件と全 producer の網羅は未検証。

現行候補には、正常なリクエストをまたがない値だけを終了・開始境界でクリアする変更を追加した。`PG(http_globals)`、`PG(modules_activated)`、SAPI の解放済み認証・本文ポインタ、executor の例外・エラー処理状態を終了時にリセットする。さらに、公式 7.4 緊急バックポートと同じ callback の境界で upload progress を無条件停止する。通常の multipart 解析とセッション機能はこの停止点を通らない。これは**限定的な緊急防御**であり、他の早期 consumer や拡張状態まで解決した証拠ではない。

停止前の限定的な差分は現在の配布物から除外した。[PHP 8.2.35 の正式修正](https://www.php.net/releases/8_2_35.php)は upload progress を維持するが、5.6 の所有権・初期化順序へ直接適用できない。緊急候補は upload progress を使うアプリの互換性を失う。`lab/check-php56-multipart.sh` の良性テストでは、停止前の OOM 候補で `MULTIPART_OK / SESSION_OK / PROGRESS_PRESENT`、最終候補のクリーンビルドで `MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT` を確認した。これは意図した機能停止と通常機能の代表確認であり、悪用不能性の証明ではない。**この候補パッチを 2 件の完全な対策として配布しない。** `checks/5.6.40.sh` はこの未完了状態を終了コード 3 で明示する。matrix の `fail (3)` はビルド失敗ではなく、この判定を表す。
