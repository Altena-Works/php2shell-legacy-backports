# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-23（日本時間）

## 現在の状態

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（要求間に残る状態）について、公式修正を PHP 5〜7 の最終 `x.y.z` へ移植する作業を扱う。**両件の全経路遮断を確認した版はまだない。** PHP 8.0/8.1 などの公式配布物は同梱しない。旧版の正常機能を維持し、攻撃コード・PoC を作成または実行しない。

追加公開情報：[php2shell-zeros](https://jackalsyn.com/posts/php2shell-zeros.html) は、修正版8.5.12でもセッション保存形式の読み書き不一致、upload progress のキー処理、拒否時のセッション消失が残ると報告する。さらに `unserialize()` の再入による UAF を報告するが、これらの記事中の再現結果と旧版への該当性は本作業では未検証。[PHP公式の検証済み Issue #24488](https://github.com/php/php-src/issues/24488)のSimpleXML/GC二重解放は8.4.27/8.5.12の別件回帰で、[公式修正コミット](https://github.com/php/php-src/commit/f963484)によりIssueは閉じられた。固定したPHP 5〜7最終版の元アーカイブ12件には原因となるGH-24050のGC追加処理がなく、[版別判定](notes/double-free-24488-triage.md)では直接該当しない。[SNS画像の元投稿](https://fedi.katze.sh/@elise/117479383739450605)には「今回修正された脆弱性とは別」という追記があると複数の引用で確認したが、Issue #24488との同一性や旧版固有の別経路は未判定。記事内のZIP・PoCは取得も実行もしていない。

公式8.2.34→8.2.35のOOM・要求境界に関連する追加行を調べた当初、7.3.33候補に変更がないファイルは48件あった。うち46件は7.3.33にも存在し、2件は存在しない。現在は `shmop_read`、Cookie、ファイル・画像処理、JSONパーサの一部、tokenizer、fileinfo/CDF、EXIF、SOAP、mbstringの入力変換・正規表現・libmbfl出力、GD/WBMPなどを候補へ移植し限定検証した。機械的な未変更・未判定リストは5件。版間の違いを個別判定する必要があり、正式版公開に必要な全経路遮断の証拠は揃っていない。詳細は[遮断範囲の監査](notes/coverage-audit-2026-10-22.md)。

| 版 | 実装・検証済みの範囲 | 残る作業 |
| --- | --- | --- |
| 5.6.40 | 機能維持候補を元アーカイブへ fuzz なし適用し、Linux/amd64・Apache/mod_php でクリーンビルド。割当上限の減算判定を追加して増分ビルドし、通常のセッション、multipart、upload progress、3 保存形式、参照値、ファイルなし投稿を再確認 | 通常 soft OOM 後はワーカーが終了する。遅延 OOM と全入口の状態消去、両 CVE の遮断は未完了 |
| 7.3.33 | 現行候補を固定済み元ソースへ fuzz なし適用。intl・OPcache・bzip2・GD・IMAPを含むLinux/amd64クリーンビルドとApache/mod_php版別検査を通過 | 個別の割当失敗地点、upload progress中の他のOOM発生地点、両CVEの全経路は未判定 |
| 5.0.5〜5.5.38、7.0.33〜7.2.34、7.4.33 | 対象版の調査・一部の元アーカイブ固定のみ | 5.6.40 と 7.3.33 の完了後に版別移植・検証 |

`patches/` は配布用、`lab/candidates/patches/` は作業候補。候補の `pass` は実施した正常系と良性 OOM の成功だけを意味する。配布用パッチへの昇格や本番導入の承認ではない。5.6.40 と 7.3.33 の配布用 `checks/` は既知の未完了条件により終了コード 3 を返す。

## 最新の検証

7.3.33 の現候補 SHA-256 は `b7f35b668d465c6be2c38a4b27f0d8169a9c200c343ade27b7ea258052b3e2b9`。固定元ソースへのfuzzなし適用、intl・OPcache・bzip2・GD・IMAP有効Linux/amd64クリーンビルド、Apache/mod_php版別検査 `pass` を確認した（`/private/tmp/php-backport-73-imap-lib-clean/patch/7.3.33/`）。生成PHPモジュール SHA-256 は `1ada1db73c1f74076dab39c12efb96166abb2823d12f23493102840359f17cfe`。通常セッション・multipart・mbstring・intl・OPcache、良性OOM後の同一Apacheワーカー継続を確認。`mb_strcut`、bzip2、GD/WBMP、IMAP MIMEヘッダーの正常系と指定した良性OOM後の同一ワーカー継続も確認した。各拡張内の別の割当失敗地点、filter内部各失敗地点、interned key固有の割当失敗、両CVEの全経路は未検証。

ExpatとIMAPの同時有効構成では、検証ビルダーにc-clientライブラリ探索用のリンクを追加した。リンクの存在は確認したが、固定ソースからの再ビルドは設定処理中にラボの3600秒制限へ達した（`/private/tmp/php-backport-73-expat-imap-clean/`）。この複合構成の動作は未判定で、上記の`pass`には含まない。

EXIF追加候補には、公式EXIF差分の複数値の失敗可能確保、結果配列のOOM後始末、解析ループの保留OOM停止、サムネイルのファイル境界検査・失敗可能確保と出力文字列の失敗処理を7.3のAPIで追加した。固定済み元ソースへのfuzzなしdry-run、Linux/amd64の既存EXIF有効構成での増分ビルド・リンク、Apache/mod_phpの通常メタデータ・サムネイル読取、既存版別チェックの終了コード0を確認。EXIF固有の各割当失敗地点は未実測で、現候補を `/private/tmp/php-backport-73-exif-expanded-clean/` でクリーンビルドし、Apache/mod_phpの版別チェック `pass`、`EXIF_OK` を確認した。生成モジュール SHA-256 は `8faf828dfaf410ca82f7df301b11de1ca13d70fecef2d63863b21cae7115550b`。

5.6.40 の遅延OOMについて公式8.2.34→8.2.35の差分を再照合した。`zend_alloc.c` のhard limit・保留状態と、VM、関数呼出し、POST、主スクリプト境界が結合している。5.6にアロケータのみを移植する案は採用しない。5.6.40候補の実装・実測状態は前回から変わらない。

直前候補のクリーンビルドでは `Zend/zend_smart_str.h:136` に `-Wstringop-overflow` 警告が出た。EXIF追加前のクリーンビルドにも同じ警告があり、今回のEXIF差分が導入したものではない。偽陽性か実際の境界不備かは未判定として別途照合する。

SOAPを7.3の旧APIに移した前候補 `da4d989a88258fcd0ed51de52342e2eec549c009c6bc83bc2e9ebd0f6e3f864e` は、固定元ソースへのfuzzなし適用、SOAP有効のLinux/amd64・Apache/mod_phpクリーンビルドと版別チェック `pass` を確認した。通常SOAP往復は `SOAP_OK`。大きな通常SOAP応答の8 MiB制限下でOOM報告と同一Apacheワーカーの次要求処理を確認した。実測はHTTP応答本文の経路のみで、chunked応答、引数・多次元復号や他の確保失敗地点は未検証。証拠は `/private/tmp/php-backport-73-soap-final-clean/patch/7.3.33/`。

mbstringではQuoted-Printable、`mb_ord`、`mb_substr_count`、MIMEヘッダ、`mb_convert_kana` の通常動作を確認した。libmbfl出力と全角・半角変換の8 MiB制限下での良性OOM報告・同一ワーカー継続も確認。GET/Cookie/POSTの直接入口、regex callback・旧 `e` モードのOOM、libmbfl各失敗地点は未実測。`mbfl_strcut` の失敗停止は候補へ追加したが、filter内部の各失敗地点と他の戻り値を無視する経路は続けて監査する。

## 次の作業

1. 7.3.33 の残る5ファイルと、実装済みCDF・tokenizer、bzip2・GD・IMAPの未実測失敗地点、upload progress中の他の復号OOM地点と要求間状態を判定する。全経路が判定できたら配布用パッチへ昇格し、指定リポジトリの作業ブランチへ速やかにpushする。
2. 5.6.40 は allocator の soft/hard 上限だけでなく、生成 VM の CALL/SWITCH/GOTO、POST・入力登録、関数呼出し、主スクリプトの境界を結合して遅延 OOM と状態消去を実装する。Linux/amd64・Apache/mod_php で通常 session と upload progress の機能を維持して検証する。
3. **この 2 版の実装と判定が終わってから**、他の PHP 5〜7 系列の最終 `x.y.z` に進む。版ごとに公式修正との機能同等性と未検証範囲を記録する。
4. 追加公開情報について、セッション保存形式の不一致・upload progress キーの検証とセッション保持、SimpleXML/GC、`unserialize()` 再入の各経路を版別に静的照合する。現候補での遮断や旧版への影響は、根拠が揃うまで主張しない。

公式公開前に作成されたローカル調査メモ4件を参照し、multipart由来SIDと `session.use_only_cookies`、セッションファイルとアプリLFI、serializer設定不一致、破棄時再入、公式修正後の非失敗可能割当を[設計書](BACKPORT-DESIGN.md#公開前メモから追加した経路の判定2026-10-22)と[残課題](notes/remaining-work-2026-10-22.md)に分類した。いずれも両CVEの修正済み判定へ自動的には加えない。

ユーザーの明示許可により `staticwebos-build` VM を正常停止した。今回は `php-backport-lab` で現候補のOPcache有効クリーンビルドと版別検査を実施した。`staticwebos-build` はこの作業では再起動していない。

ユーザーがGitHub証明書について通常のpushを許可したため、TLS検証を無効化せず作業ブランチへ送信できた。main/masterへのpushは行わない。

## 参照先

- [5ターンの実行計画](notes/five-turn-execution-2026-10-22.md)
- [設計と版別状態](BACKPORT-DESIGN.md)
- [候補の説明](lab/candidates/README.md)
- [検証ラボ](lab/README.md)
- [5.6.40 の版別調査](notes/php-5.6.40.md)
- [遮断範囲の監査](notes/coverage-audit-2026-10-22.md)
- [残課題の棚卸し](notes/remaining-work-2026-10-22.md)
- [二重解放の版別判定](notes/double-free-24488-triage.md)
- [前回までの詳細記録](archive/HANDOFF-2026-10-22-before-fallible.md)
