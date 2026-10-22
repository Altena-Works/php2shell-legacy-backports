# CVE-2026-109618 / CVE-2026-109619 遮断範囲の監査

確認日：2026-10-22。対象は現行の PHP 7.3.33 候補パッチ。**全経路遮断の確認は未完了で、配布用パッチへの昇格条件を満たさない。**

## 公式差分との照合

ローカルの PHP 8.2.34 と 8.2.35 の `.c` / `.h` 差分から、追加行に `OOM`、`fallible`、`falloc`、`finit`、`finsert`、`fadd`、`RINIT`、`RSHUTDOWN` などが現れるファイルを抽出し、7.3.33 候補パッチの変更ファイルと照合した。この文字列による抽出は**調査対象の優先順位付け**であり、脆弱性の有無や移植の等価性を証明しない。異なる PHP 版でファイルや実装が存在しない場合もある。

候補に変更がない該当ファイルは48件：Zend 6件、拡張41件、SAPI 1件。7.3.33 の元ソースとファイル名を照合すると、46件は存在し、`ext/opcache/jit/zend_jit_disasm.c` と `sapi/fuzzer/fuzzer-sapi.c` の2件は存在しない。**存在する46件がすべて脆弱という意味ではなく、該当性と同等の対処を個別判定する必要がある。** 特に Zend の `zend_API.c`、`zend_compile.c`、`zend_operators.c`、`zend_smart_str.c` / `.h`、`zend_string.c`、拡張の JSON パーサ、PCRE、SimpleXML、SPL、mbstring、zlib、標準関数群を調べる。`main/streams/memory.c` は変更を追加したため件数から外れ、クリーンビルドと指定経路の良性検査を通過した。候補に変更があるファイルも、行単位で等価性を確認したわけではない。

## 現時点の検証境界

`ext/shmop/shmop.c` は初回の未変更48件に含まれていた。7.3.33 の `shmop_read` に公式8.2.35相当の失敗可能な文字列割当と OOM 中断を追加した。`shmop` 有効の Linux/amd64・Apache/mod_php クリーンビルド、通常の読み書き、12MiB読み取りの良性OOM後の同一ワーカー継続を確認した。初回抽出の残り47件は個別判定が必要であり、この件の確認も他の `shmop` 経路を網羅しない。

`ext/standard/head.c` の Cookie 値追加には失敗可能な `smart_str` 拡張を移した。`Zend/zend_smart_str.c` / `.h` に必要な非永続バッファの拡張 API を追加し、Linux/amd64・Apache/mod_php で通常の `setcookie` / `setrawcookie` と大型の生値による良性OOM後の同一ワーカー継続を確認した。公式の `smart_str` 差分には永続バッファと他の呼び出し先も含まれるため、これら2ファイル全体の等価性はまだ判定しない。

`ext/standard/html.c` の初期確保と2つの再確保、`ext/standard/levenshtein.c` の作業配列確保を失敗可能にした。HTML の初回案は OOM エラーを表示する側でも失敗可能割当を使い、既存の JSON 良性OOM検査でエラー文が空になった。OOM 保留中は従来の割当を使う条件に修正し、クリーンビルドと Apache/mod_php の JSON エラー表示、通常 HTML 変換、大型入力の良性OOM、同一ワーカー継続を確認した。`levenshtein` の通常値・重み付き値・旧版の長さ超過も確認した。HTML の再確保2地点と `levenshtein` の割当失敗そのものは動的に発生させていない。

`ext/standard/file.c` と `image.c` には、公式8.2.35の行分割・CSV・XBMでの保留 OOM 中断、`fgets` の失敗可能なコピー、SWF 再確保の失敗処理に対応する7.3.33差分を追加した。Linux/amd64・Apache/mod_phpのクリーンビルド、通常のファイル読取・CSV・XBMと既存の良性OOM検査を通過した。追加割当失敗をそれぞれ強制する動的検査や、両ファイル全体の等価性は未確認。

`Zend/zend_objects.c` / `.h` と `zend_API.c` / `.h`、`ext/json/json_parser.y` / `.tab.c` に、JSONのオブジェクト・配列生成失敗と要素追加後の保留OOM中断を追加した。固定ソースへの厳密適用、Linux/amd64・Apache/mod_phpのクリーンビルド、通常のJSON復号と良性OOM後の同一ワーカー継続を確認した。OOMがどの割当で生じたかは未特定。旧版のハッシュ挿入は公式8.2.35の失敗可能APIそのものには変更しておらず、直後の保留OOM確認による同等性は未判定。抽出条件に該当する未変更ファイルは機械的照合で33件残り、該当性と行単位の等価性は別途判定する。

`ext/standard/var_unserializer.re` / `.c` のエスケープ文字列、クラス名、通常文字列・キーに失敗可能な割当と保留OOM確認を追加した。旧版の文字列キー interned 化は維持する。固定ソースへの厳密適用、Linux/amd64・Apache/mod_phpのクリーンビルド、3保存形式と許可クラス・不完全クラス・長いキーの通常動作、セッション復号の良性OOM後の同一ワーカー継続を確認した。クラス検索の小文字化も失敗可能な一時文字列へ移し、保留OOMなら復号を中断する。3保存形式で、大文字小文字の異なる許可クラス名、無害なクラス定義コールバック後の再検索を確認した。各割当失敗地点の個別動的検査と、公式のinterned string用失敗可能APIとの差の全条件は未判定。

`ext/pcre/php_pcre.c` では `preg_replace` とコールバック置換の結果バッファを失敗可能な確保・再確保へ変更し、コールバック引数構築中の保留OOMを関数呼出し前に中断する。`preg_match`・`preg_match_all` の結果配列構築と `preg_split` の反復でも保留OOMを検知し、部分結果を破棄する。固定ソースへのfuzzなし適用、Linux/amd64・Apache/mod_phpクリーンビルド、5関数の通常動作、`preg_replace` と `preg_match_all` の良性OOM後の同一ワーカー継続を確認した。旧版のPCRE2コンテキストは永続領域にあり、公式8.2.35のリクエスト割当器を機械的に移していない。同じ固定ビルドの追加検査で、名前付き・オフセット付き結果、集合順、区切り捕捉の通常動作と、パターン順・オフセット付き・集合順・分割の4分岐の良性OOM後の同一ワーカー継続を確認した。PCRE内部割当、マッチ・分割の個別失敗点、コールバック処理中のOOM、各再確保地点の個別失敗は未判定で、PCRE全体の等価性は未確認。

`ext/spl/spl_fixedarray.c` の配列初期化・拡張を失敗可能な割当へ変更し、各呼び出し元へ失敗を伝播させた。縮小では要素破棄後の再確保を避ける。`ext/curl/interface.c` の `CURLOPT_RETURNTRANSFER` 用受信バッファにも失敗可能な拡張を追加し、失敗を libcurl へ返す。7.3.33 を cURL 有効で Linux/amd64・Apache/mod_php クリーンビルドし、SPL とコンテナ内 `file://` cURL の通常動作・良性OOM後の同一ワーカー継続を確認した。SPL の複製・復元、cURL の別モードや個別失敗地点は未判定。

`ext/zlib/zlib.c` は公式の失敗可能な圧縮初期確保、展開バッファ拡張、`gzfile` の保留OOM確認に対応した。7.3.33 の追加の初期確保・`deflate_add` 拡張も失敗可能にし、失敗時に保有バッファを解放して中断する。cURL と zlib 有効の Linux/amd64・Apache/mod_php クリーンビルド、通常の gzip 読み書き、逐次展開と一括展開中の良性OOM後の同一ワーカー継続を確認した。zlib の個別失敗地点と圧縮中のOOMは未判定。

`ext/simplexml/simplexml.c` では、公式差分の文字列確保、プロパティ走査中の OOM 中断、移動した iterator データの復元、XPath の配列確保失敗処理を7.3.33に対応させた。公式版の `SimpleXMLElement::key()` に相当する旧版の iterator コールバックも失敗可能な確保へ変更した。旧版では文字列化コールバックから失敗を返すだけだと OOM 後にユーザーコードが次の文まで進む実測があり、一時 libxml データの解放後に保留 OOM を処理する境界を追加した。`ext/libxml/libxml.c` のエラー処理中断とエラー配列のサイズ指定も公式差分に対応した。libxml・SimpleXML 有効の固定ソースへの厳密適用、Linux/amd64・Apache/mod_php クリーンビルド、通常の XML 文字列化・属性・XPath・iterator キー・内部エラー列挙と、12 MiB の良性テキストに対する8 MiB制限下の soft OOM 後の同一 worker 継続を確認した。個別の属性・XPath・iterator の割当失敗地点、拡張全体の同等性は未判定。

`ext/iconv/iconv.c` では、公式差分に対応する変換結果と MIME ヘッダー用バッファの失敗可能な確保・拡張、ヘッダー反復とフィルター処理の保留 OOM 判定を旧版の API に合わせて追加した。GNU iconv 以外の分岐にある変換結果バッファも同じ失敗処理に変更した。固定ソースへの厳密適用、iconv 有効の Linux/amd64・Apache/mod_php クリーンビルド、通常の `iconv`・`iconv_mime_encode`・変換フィルターと、4 MiB の良性入力を8 MiB制限下でUTF-16LEへ変換したときの soft OOM 後の同一 worker 継続を確認した。これは一つの割当失敗条件に限り、MIME・フィルターの個別 OOM 地点と非 GNU iconv の実行時動作は未判定。

`ext/dom/xpath.c` のXPathノード集合を返す配列は、公式差分に対応して旧版の `zend_hash_real_finit` で失敗可能に初期化し、要素追加後の保留OOMでは部分配列とXPath結果を解放する。`ext/xmlwriter/php_xmlwriter.c` のメモリ出力は失敗可能な文字列確保に変更した。DOM・XMLWriter 有効の固定ソースへの厳密適用、Linux/amd64・Apache/mod_php クリーンビルド、通常のDOM XPath結果とXMLWriter出力、12 MiB の良性出力に対する8 MiB制限下のXMLWriter soft OOM 後の同一 worker 継続を確認した。XPath配列の割当失敗地点とノード生成中のOOMは未実測で、DOM全体の同等性は未判定。

`ext/xml/xml.c` には、旧版で必要な `ltags` のゼロ初期化と部分解放、SAXコールバック中の保留OOM中断を一組で追加した。固定ソースへfuzzなし適用し、libxml構成で通常のSAX・構造化解析と良性OOM後の同一ワーカー再利用を確認した。さらに、上流の[Expat構成の非失敗可能割当報告](https://github.com/php/php-src/issues/24492)に対応し、Expat用のmalloc/realloc wrapperを失敗可能な割当へ変更し、パーサ生成失敗と解析後の保留OOMを安全な地点で処理する。Expat構成でも固定ソースからのクリーンビルド、実装識別、通常XMLと指定した良性OOM後の同一Apacheワーカー再利用を確認した。両構成の全割当失敗地点を検証した意味ではない。

`ext/json/json_scanner.re` と生成済み `json_scanner.c` では、公式8.2.35がJSON文字列用確保を失敗可能にした一箇所を7.3.33の `zend_string_safe_falloc()` へ移した。固定ソースへのfuzzなし適用、Linux/amd64・Apache/mod_phpクリーンビルド、通常JSON復号、良性の長いJSON文字列で8MiB制限に達した後の同一ワーカー再利用を確認した。`bz2.c` と `bz2_filter.c` の公式差分を候補に追加し、固定元ソースへのfuzzなし適用と、既存ビルドヘッダ・ローカルSDKの `bzlib.h` を用いたLinux/amd64構文・型検査を確認した。隔離ビルダーにbzip2開発ファイルがないため、リンクとApache実動作は未検証。

`tokenizer/tokenizer.c` は7.3.33にも存在し、通常の `token_get_all()` と `TOKEN_PARSE` の両経路が `add_token()` を呼ぶ。8.2.35の公式修正は、トークン文字列の確保失敗を呼び出し元へ返し、字句解析を止める。7.3.33候補でも文字列を失敗可能に確保してからトークンへ組み込み、通常経路は失敗時に走査を止めて部分的な結果を破棄し、`TOKEN_PARSE` はコールバックで失敗状態を保持して結果を破棄するよう変更した。現候補SHA-256 `19fc874524167fa322f87de7d43ddef59bc0067860351dcfe18e78e19642502e` を固定元ソースへfuzzなし適用し、tokenizer有効のLinux/amd64・Apache/mod_phpでクリーンビルドと版別チェックを通過。通常の短い入力と、8 MiB制限下の良性の長いPHPコメントを確認した。後者では通常モードと `TOKEN_PARSE` の両方がトークン文字列の確保量に一致する `2200036` バイトの失敗で中断し、同じApache workerが次の要求を処理した。これは指定したトークンと失敗地点の証拠であり、全トークン種別・全失敗地点を証明しない。

`fileinfo/libmagic/cdf.c` の公式修正はCDF解析で使う malloc、realloc、calloc の3入口を失敗可能にする。7.3.33候補では旧版の `_femalloc()` と `_safe_ferealloc()` / `_safe_femalloc()` に移し、calloc相当では成功時だけゼロ初期化する。現候補はfileinfo有効の同じクリーンビルドでコンパイルされ、既存のPowerPoint形式ファイルを `application/vnd.ms-powerpoint` と判定した。CDF解析中の割当失敗と各呼び出し元の後始末は未実測。

追加候補では `zlib_filter.c` の2か所の保留OOM中断と、`main/streams/streams.c` のフィルター入力・読取バッファ・結果文字列の失敗可能な確保を移した。最初の候補は `stream_get_contents()` による良性の大容量展開で Apache worker が hard OOM により終了した。読取バッファと結果文字列の再確保を変更後、指定経路で soft OOM と同一 worker 継続を確認した。さらにフィルター入力バッファと区切り文字付き読取の返却文字列を公式差分に合わせ、後述のセッション復号修正も含めて固定ソースへの厳密適用、Linux/amd64・Apache/mod_php クリーンビルド、版別チェックを通過した。同じバイナリで通常フィルター動作と良性OOM後の同一 worker 継続を確認。個別の割当失敗地点と zlib 圧縮中のOOMは未判定。

### 8.5.12 の二重解放報告

[報告者の原投稿](https://fedi.katze.sh/@elise/117479383739450605) は、ASan を有効にした PHP 8.5.12 の CLI 実行で二重解放が報告された画面を示す。2026-10-22 04:56 の追記で、報告者自身が「この問題は当日修正された2件とは別」と明記した。公開画面では原因箇所と再現入力が伏せられており、[PHP公式の検証済みIssue #24488](https://github.com/php/php-src/issues/24488)と同一事象とは確定できない。Issue #24488のSimpleXML/GC回帰については、[版別判定](double-free-24488-triage.md)で7.3.33と5.6.40のGCに原因となる新規ハンクがないことを確認した。旧版固有の別経路やSNS投稿の原因は未判定であり、両CVEの公式修正漏れとは主張しない。

### 7.3.33 の要求境界と Zend 基盤

現行候補の `ext/session/session.c` では、multipart 開始時にセッションの要求状態を初期化し、進捗更新中の3種類の保存形式で不完全クラスとして復号・再符号化する。`php_session_rfc1867_update()` と cleanup は失敗時も `in_rfc1867_update` を解除し、multipart 終了時には進捗データを解放して `rfc1867_progress` を `NULL` に戻す。これは公式8.2.35の要求境界修正に対応する静的確認であり、すべての中断地点での実行時確認ではない。

[PHP 8.5.12 の機能退行報告](https://github.com/php/php-src/issues/24493)では、制限付き復号が合法な予約名プロパティを拒否したとき、進捗処理が保存済みセッションを破棄する。[公開された修正候補](https://github.com/lazerg/php-src/commit/a45ffe71a56741579f648d969193bd027a783e36)はこの場合に更新だけを中止する。7.3.33 候補にも同じ破棄経路があったため、進捗中の復号失敗で `php_session_abort()` を使う修正を追加した。さらに旧版の `php_serialize` 復号器は失敗時にも常に成功を返しており、予約名プロパティを失って進捗を書き戻した。公式8.2系の戻り値条件に合わせて失敗を返すよう変更した。固定ソースへの厳密適用と Linux/amd64・Apache/mod_php クリーンビルドの後、同じバイナリで `php`、`php_binary`、`php_serialize` の通常 multipart と、予約名プロパティを含む保存済みセッションの保持を確認した。

別の良性セッション復号OOM検査では、8 MiB 制限下で要求スクリプトが実行されず、同一 Apache worker が次の要求を処理し、保存済みセッションファイルの SHA-256 が前後で一致した。これは実際に発生した一つの失敗地点と files 保存ハンドラの結果であり、全保存ハンドラ・全OOM地点を示さない。

Zend側の当初未移植だった差分6ファイルを確認した。`zend_API.c` の `object_finit` は JSON 用に追加済み。`zend_smart_str.c` / `.h` は Cookie の経路を部分移植した。`zend_operators.c` の公式追加は復号時の小文字化を失敗可能にする呼出しに使われる。7.3.33では `var_unserializer` 内で失敗可能な小文字名を作って既存のクラス検索APIへ渡す形にした。公式の `zend_string.c` と `zend_compile.c` の追加は新規の `interned_strings_fallible` フラグを支えるもので、7.3.33候補はそのフラグを導入せず復号側の文字列を失敗可能に確保している。これらの行を機械的に移植する必要はないが、OPcache上書きやinterned表の割当失敗を含む同等性は未判定。smart_str の残る経路は7.3.33に公式と同名のAPIがないため、呼び出し側の所有権処理と合わせて未判定のまま調べる。

残る同名5ファイルのうち、`Zend/zend_compile.c` の公式差分は `interned_strings_fallible` の要求初期化だけである。7.3.33にはこのフラグがなく、候補は復号キーを `zend_string_safe_falloc()` で作って `zend_string_init_interned()` を通さない。`Zend/zend_string.c` と `Zend/zend_operators.c` の公式差分もこの失敗可能な interned string・小文字化 API に依存する。候補の代替経路は実装済み。OPcache有効のApache/mod_phpで通常セッション・multipartと良性OOM後の同一ワーカー継続は通過したが、interned key固有の割当失敗は未実測。`ext/mbstring/libmbfl/mbfl/mbfl_encoding.h` の公式差分は `mb_convert_buf` の再確保であり、この型とマクロは7.3.33に存在しない。旧版の対応経路は `mbfl_memory_device_realloc()` とfilter出力なので、候補に変更したそれらの失敗伝播を引き続き監査する。これらは同名ファイルの差分をそのまま移せない理由であり、全経路遮断の証明ではない。

`ext/opcache/ZendAccelerator.c` の公式差分には、失敗可能な文字列初期化に加え、永続化中のCE cache slotを公開前まで保留する処理がある。7.3.33にはその処理が使う `ZSTR_HAS_CE_CACHE`、`IS_STR_CLASS_NAME_MAP_PTR`、`ZEND_MAP_PTR_NEW_OFFSET` がないため、CE cache slot部分は同じ形では適用できない。旧版のinterned string処理の全経路同等性は未判定。
同ファイルの公式差分末尾にあるpreload用 `php_request_startup()` 直後の割当回数制限解除も、7.3.33の同ファイルにはpreload入口がない。これも同名ファイルへの機械的な移植対象から外す。候補のセッション復号キー生成は interned string handler を通さない。OPcache有効の通常系と良性OOM後の同一ワーカー継続は実測済みだが、各失敗地点は未実測。

- 7.3.33 現行候補は固定済み元ソースへの fuzz なし適用、Linux/amd64 クリーンビルド、Apache/mod_php の指定経路の正常系と良性OOMを確認。`array_pad` は公式の挿入ごとの失敗処理と異なる事前確保案であり、参照数を含む全状態の等価性は未判定。
- 7.3.33 の前候補は Linux/amd64・Apache/mod_php で一部の正常系と良性OOM後のワーカー継続を確認した。CVE-2026-109618 の全OOM入口、CVE-2026-109619 の全要求境界は未確認。
- 5.6.40 の機能維持候補は通常 soft OOM でワーカー交代が観測され、公式同等修正には到達していない。その他の PHP 5〜7 最終 `x.y.z` は版別の実装・検証が未完了。
- ユーザーの明示許可により `staticwebos-build` VMを正常停止し、`php-backport-lab` で検証を実施した。

正式版を公開するには、版ごとに公式修正の適用可能な入口を網羅し、元ソースへの適用、Linux x86_64・Apache/mod_php のビルド、旧版の正常機能、良性OOM後の要求中断と同一ワーカー再利用、要求間状態の消去を確認する。未判定の入口が残る版は正式版として表示しない。
