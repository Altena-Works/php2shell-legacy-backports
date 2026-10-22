# 残課題の棚卸し（2026-10-22）

対象は CVE-2026-109618、CVE-2026-109619 の旧版バックポートと、別件として報告された PHP 8.5.12 の二重解放。ここに挙げた未判定箇所を脆弱と断定しない。公式 8.2.34→8.2.35 の差分と現行候補の照合は[遮断範囲の監査](coverage-audit-2026-10-22.md)を参照する。

| 優先 | 残る作業 | 完了を示す証拠 |
| --- | --- | --- |
| 1 | 7.3.33 の公式差分で未判定の拡張・入口を版別に判定する。SimpleXML、mbstring、iconv、DOM、XML 系、zlib などを優先し、該当箇所は機能を保って移植 | 各箇所の該当性と変更理由、正常動作・良性 OOM の必要最小限の実測。未搭載機能は構成上の根拠 |
| 1 | 7.3.33 の upload progress 中の復号・書戻し、OOM 中断、次リクエストへの状態残留を監査する | 3 保存形式の正常動作と、良性の失敗条件における中断・同一ワーカー再利用・要求境界の確認。攻撃コードは使わない |
| 1 | 7.3.33 の全対象経路を公式修正と照合し、配布用パッチへ昇格する | 行・状態寿命単位の照合、クリーンビルドと機能維持、未判定の対象経路がないことを示す監査記録 |
| 2 | 5.6.40 の soft OOM で Apache ワーカーが終了する問題を解決し、7.3.33 と同等の防御を旧 API に移す | 固定ソースへの適用、Linux x86_64・Apache/mod_php の正常機能と良性 OOM 後の同一ワーカー継続 |
| 3 | PHP 5.0.5〜5.5.38、7.0.33〜7.2.34、7.4.33 の各系列最終版を判定・移植する | 版別パッチ、構成とソースの固定、正常機能・防御条件の版別実測。対象外なら根拠 |
| 別件 | 8.5.12 の二重解放報告の原因と旧版への該当性を確認し、該当すれば修正する | 公開された一次資料・公式応答で原因と影響を特定し、該当版で防御的に修正・検証。現時点で原因と再現条件は非公開 |
| 最後 | 版別成果物と導入説明を整え、指定リポジトリへ送信する | 配布用パッチとチェックの整合、送信経路の証明書拒否・認証条件、リモートコミットの確認 |

現行候補の `pass` は実施した範囲に限る。全経路遮断を証明するまで「公式修正と同等」「正式版」と表示しない。上記の判定・実装・検証・送信を終えた時点で一度区切る。

今回閉じた具体的な失敗: zlib フィルターだけを変更した候補は、12 MiB の良性展開を8 MiB の制限下で `stream_get_contents` すると worker が hard OOM で終了した。ストリーム読取バッファと結果文字列の再確保を失敗可能にした現候補は、固定ソースへの厳密適用、Linux/amd64・Apache/mod_php クリーンビルド、通常フィルター動作、soft OOM 後の同一 worker 継続を通過した。また、upload progress の制限付き復号で合法な予約名プロパティを拒否した場合に保存済みセッションを破棄しない修正は、3 保存形式の通常 multipart と予約名プロパティ保持を通過した。指定したセッション復号OOM地点では保存ファイルの SHA-256 が前後一致した。いずれも個別の確認であり、圧縮中や他のOOM失敗地点、全保存ハンドラは未判定。

## 7.3.33 の未変更・未判定ファイル

公式 8.2.34→8.2.35 の追加行に OOM・失敗可能 API・要求初期化を示す語があり、7.3.33 に同名ファイルが存在するが現候補パッチでは直接変更していないものが26件ある。これは機械的な調査リストであり、26件すべてへの変更が必要という意味ではない。版差による代替処理と拡張の搭載有無も調べる。

- Zend: `zend_compile.c`、`zend_operators.c`、`zend_string.c`。復号側の代替実装を含め、同等性を判定する。
- 拡張: `bz2/bz2.c`、`bz2/bz2_filter.c`、`dom/xpath.c`、`exif/exif.c`、`fileinfo/libmagic/cdf.c`、`gd/libgd/wbmp.c`、`iconv/iconv.c`、`imap/php_imap.c`、`intl/converter/converter.c`、`intl/normalizer/normalizer_normalize.c`、`json/json_scanner.c`、`mbstring/libmbfl/mbfl/mbfl_encoding.h`、`mbstring/libmbfl/mbfl/mbfl_memory_device.c`、`mbstring/mb_gpc.c`、`mbstring/mbstring.c`、`mbstring/php_mbregex.c`、`opcache/ZendAccelerator.c`、`soap/php_encoding.c`、`soap/php_http.c`、`soap/soap.c`、`tokenizer/tokenizer.c`、`xml/xml.c`、`xmlwriter/php_xmlwriter.c`。`zlib/zlib_filter.c`、`libxml/libxml.c`、`simplexml/simplexml.c` は変更済みだが個々の失敗地点は未判定。

候補パッチに含まれるファイルも行単位の等価性は未証明。特にセッションの異常終了境界、JSON/PCRE内部割当、SPLの複製・復元、cURLの他モード、zlibの各割当地点を別に扱う。
