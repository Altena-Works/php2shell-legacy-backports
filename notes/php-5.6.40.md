# PHP 5.6.40 緊急候補の状態

元ソースは PHP 公式配布の `php-5.6.40.tar.gz`（SHA-256 `56fb9878d12fdd921f6a0897e919f4e980d930160e154cbde2cc6d9206a27cac`）。`ext/session/session.c` の照合値は `ae7286b24e1417ed2cef2e59d94525d5fe293cfb7cebc3be383800df78f621b6`。

## CVE-2026-109618

遅延OOMを機能維持で移植する際のVM境界を追加調査した。5.6.40の生成済み`Zend/zend_vm_execute.h`はCALL型で演算ごとに`execute_ex()`のループへ戻るが、`Zend/zend_vm_gen.php`はSWITCH型とGOTO型も生成でき、GOTO型の`ZEND_VM_CONTINUE()`は次のhandlerへ直接分岐する。したがってCALL型ループだけに保留OOM確認を加えても、全ビルドの安全地点を覆えない。`Zend/zend_vm_execute.skl`・生成器・生成済みVMを整合させる必要がある。また`ZEND_HANDLE_EXCEPTION`は`EG(opline_before_exception)`から演算位置を直ちに計算し、catch/finallyへ配送する。7.3の内部巻き戻し状態をそのまま移すことはできず、5.6の`zval *`例外とVMスタック後始末に合わせた独立実装が必要。これはソース調査段階であり、実装・検証結果ではない。

2026-10-22 の追加ソース照合で、遅延 OOM の最小結合単位を具体化した。`Zend/zend_alloc.c` の通常の上限判定は `_zend_mm_alloc_int()` と `_zend_mm_realloc_int()` にあり、現候補の `zend_set_memory_limit()` は soft limit だけを設定する。`heap->overflow` は初期化・リセットされるが、割当時の上限回避や保留エラー配送には使われていない。したがって、アロケータの即時終了だけを保留フラグへ置き換えると、エラー報告自体が同じ上限へ再突入し得る。独立した hard limit、保留情報の要求寿命、報告時の再入防止を同時に設ける必要がある。

配送地点は生成済み CALL 型の `execute_ex()` ループだけでは足りない。`Zend/zend_vm_gen.php` は CALL の `ZEND_VM_CONTINUE()` を `return 0`、SWITCH を共有ラベルへの分岐、GOTO を次 handler への直接分岐として生成する。`ZEND_VM_RETURN()`・`ENTER()`・`LEAVE()` と `ZEND_VM_DISPATCH()` も別経路であり、生成テンプレート・生成器・生成済み VM を一組で確認する。VM 外では `main/main.c` の `php_request_startup()` が `zend_activate()` 後に `sapi_activate()` と `php_hash_environment()` を呼び、モジュール初期化前に POST を処理する。`main/SAPI.c` の読取・POST handler から戻った後、`Zend/zend_execute_API.c` の関数呼び出し後、`Zend/zend.c` の主スクリプト終了時にも保留状態を安全に届ける境界が要る。これは実装箇所の特定であり、遅延 OOM が実装・検証済みという意味ではない。

PHP 5.6.40 の `Zend/zend_alloc.c` は OOM 時に `zend_mm_safe_error()` から `zend_bailout()` を呼ぶ。Apache/mod_php はリクエスト開始が失敗しても終了処理へ進む。この組み合わせは [PHP 公式の説明](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)にある危険な状態遷移と一致する。

`patches/php-5.6.40.patch`（SHA-256 `538e8b0543607bf15227697b6473938dbf4cfde8a0781ed604e308e8777c9899`）は、[PHP 公式の 7.4 向け最小バックポート](https://github.com/php/php-src/tree/PHP-7.4-CVE-2026-109618-109619)と同じ安全側の方法で、OOM と関連する割当サイズのオーバーフロー時にワーカーを即時終了させる。`zend_strtod.c` の `Balloc()` での割当失敗も含む。通常の割当経路は変更しない。OOM 時に PHP の通常のエラーハンドラやシャットダウン処理が動かなくなる挙動変更がある。最終候補は元ソースからの fuzz なし適用・クリーンビルドを通り、隔離 Linux/amd64・Apache/mod_php で通常セッション HTTP を確認した。制御された OOM 後のワーカー回復は未確認。

2026-10-22 の追加照合では、元アーカイブのハッシュ確認、fuzz なしの適用、修正後の対象 7 ファイルの SHA-256 照合、既存の静的安全条件、Apache/mod_php の通常動作、良性 multipart 投稿を確認した。`checks/5.6.40.sh` は対象ファイルの一致を確認した後も、別経路が未調査のため終了コード 3 を保つ。これは公式最小バックポートで用いた**検証項目**へ近づけるものであり、同等の防御範囲を立証するものではない。

同日の良性 `memory_limit` 超過検査では、現行の機能維持候補をロードした Apache ワーカーの HTTP 接続が `curl 52` で切れ、次の要求を別 PID のワーカーが処理した（PID 52 → 62）。これは現行の `_exit(1)` 経路を実機に近い構成で確認した結果であり、通常の soft OOM 後に同じワーカーを使える修正は未実装である。

同じラボ構成で元ソースから無修正版を再ビルドした。無修正版は `baseline pass`、修正候補は既知の未完了判定による `fail (3)` で、どちらも `5.6.40 / apache2handler / SESSION_OK` を返した。良性 multipart 検査は無修正版が `MULTIPART_OK / SESSION_OK / PROGRESS_PRESENT`、修正候補が `MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT`。ビルドした `libphp5.so` の SHA-256 は無修正版 `c3b5a44ec30bb84b085a42453ead4ff356aca41859f42ca0f19079965e1a054e`、修正候補 `40090cd73b758fbdf58ebbb82a6aa0a86fe6e8427ded9f49fa13dd1fb5bb1d58`。

## CVE-2026-109619

**緊急緩和を追加したが、完全遮断は未検証。** PHP 5.6.40 の upload progress カウンタは独立して確保した `zval *` であり、8.x の HashTable bucket ポインタと同じ実装ではない。また、5.6 の `last_error` の文字列は `strdup` / `free` で管理される。これらの相違だけで安全とは判定できない。リクエストをまたいで残る session、executor、SAPI、拡張状態について、具体的な producer / consumer と正常動作への影響を調べる必要がある。

さらに、5.6 の session decoder は `PHP_VAR_UNSERIALIZE_INIT` を使い、unserializer は `__wakeup` や設定された callback を呼び得る。8.2.35 は upload progress 中にのみ不完全クラスとして扱うための専用モードを追加したが、5.6 に対応 API はない。機能を維持して同じ境界を作るには unserializer を含む移植が要る。

5.6 の候補経路として、アップロード中の `php_session_initialize()` は `php_session_track_init()` で `PS(http_session_vars)` を公開してから session の読取・復号を行う。復号時の callback や fatal interruption により対応する終了処理が飛ぶ可能性がある。次のリクエストで通常の RINIT より先に動く upload progress と INI 診断は、[公式 advisory](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)が示す早期 consumer である。5.6 の `zend_error()` は入口で `EG(exception)` を読み、従来の `shutdown_executor()` はその値を最後に必ず消す実装ではなかった。ただし、5.6 でこれらが組み合わさる具体的な悪用条件と全 producer の網羅は未検証。

現行候補には、正常なリクエストをまたがない値だけを終了・開始境界でクリアする変更を追加した。`PG(http_globals)`、`PG(modules_activated)`、SAPI の解放済み認証・本文ポインタ、executor の例外・エラー処理状態を終了時にリセットする。さらに、公式 7.4 緊急バックポートと同じ callback の境界で upload progress を無条件停止する。通常の multipart 解析とセッション機能はこの停止点を通らない。これは**限定的な緊急防御**であり、他の早期 consumer や拡張状態まで解決した証拠ではない。

[追加の作業候補](../lab/candidates/README.md)は、終了処理の後半で新たに設定された `last_error_message` と `last_error_file` もメモリ管理終了前に消す。PHP 5.6.40 の元アーカイブに厳密適用し、Linux/amd64・Apache/mod_php でクリーンビルド、通常セッション・multipart を確認した。後処理診断を動的に発生させた確認や、CVE-2026-109619 の全入口の遮断確認は未実施。既存の配布用緊急パッチとは別の未完成候補である。

停止前の限定的な差分は現在の配布物から除外した。[PHP 8.2.35 の正式修正](https://www.php.net/releases/8_2_35.php)は upload progress を維持するが、5.6 の所有権・初期化順序へ直接適用できない。緊急候補は upload progress を使うアプリの互換性を失う。`lab/check-php56-multipart.sh` の良性テストでは、停止前の OOM 候補で `MULTIPART_OK / SESSION_OK / PROGRESS_PRESENT`、最終候補のクリーンビルドで `MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT` を確認した。これは意図した機能停止と通常機能の代表確認であり、悪用不能性の証明ではない。**この候補パッチを 2 件の完全な対策として配布しない。** `checks/5.6.40.sh` はこの未完了状態を終了コード 3 で明示する。matrix の `fail (3)` はビルド失敗ではなく、この判定を表す。

機能維持候補では、公式 8.2.35 の早期更新失敗条件を 5.6 の API に合わせて追加した。`php_session_initialize()` は失敗を返し、upload progress の更新・削除は成功かつ active の場合だけ進める。通常のセッション読取失敗に対する旧版の扱いは維持し、早期更新時だけ失敗を報告して状態を閉じる。元アーカイブへの fuzz なし適用、Linux/amd64・Apache/mod_php のクリーンビルドと最終 `session.c` の増分コンパイル後、通常の進捗・セッション値維持と、存在しない保存先での警告・通常アップロード・同一ワーカーの次要求を確認した。これは CVE-2026-109619 の一つの境界確認であり、全経路の遮断判定ではない。

5.6 の `ZEND_SET_SYMBOL_WITH_LENGTH` は既存スロットが参照値なら、`progress->data` の値を既存 `zval` へ移して元の本体を `FREE_ZVAL` する。進捗構造体のポインタをそのままにすると、次の更新で解放済み本体を参照する。機能維持候補では参照先の `zval` を挿入前に保持し、更新後に `progress->data` を付け替える。Linux/amd64・Apache/mod_php で通常の参照値を持つセッションを作り、小さな multipart 投稿後に進捗キーと別キーの参照関係、進捗の記録を確認した。攻撃コードは使っていない。他のセッション形式・例外経路の網羅は未了。
