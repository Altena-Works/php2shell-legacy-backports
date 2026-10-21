# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-22（日本時間）

## 現在の成果物と判定

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（リクエスト間に残る状態）について、公式バックポートがない PHP 5〜7 への独自移植を扱う。**両件を完全に遮断した版は、現時点の記録にはない。** PHP 7.4、8.0、8.1 向けの公式最小バックポートは同梱せず、公式配布元を参照する。

| 版 | 記録されている到達点 | 残る判定 |
| --- | --- | --- |
| 5.6.40 | 機能維持候補を固定済み公式アーカイブから fuzz なしで適用・クリーンビルド。Linux/amd64・Apache/mod_php で通常セッション・multipart・進捗、3 種類の保存形式、参照値、ファイルなし投稿を確認 | 両 CVE の全経路遮断、soft OOM 後の同一ワーカー継続、他の設定・異常系は未確認 |
| 7.3.33 | 機能維持候補に遅延 OOM と JSON 中断判定を追加。JSON/filter を含む Apache/mod_php の通常セッション・multipart・進捗、良性 JSON soft OOM 後の同一ワーカー再利用を確認 | 大きな単一割当・別の OOM 経路、両件の完全遮断は未実証 |
| 5.0.5 / 5.1.6 / 5.2.17 / 5.3.29 | 公式アーカイブの SHA-256 を固定。session ソースに upload progress シンボルなし | OOM と他の要求間状態、実行動作は未判定 |
| 5.4.45 / 5.5.38 / 7.0.33 / 7.1.33 / 7.2.34 | 対応パッチは未完成 | 導入対象外 |

7.3.29 は同じ 7.3 系列の最終版ではないため、候補パッチ・検査・ハッシュを配布物から除いた。7.4.33、8.0.30、8.1.34 の公式差分と版専用の検査・記録も配布物から除いた。[README](README.md) は独自移植だけを検証候補として示す。5.6.40 と 7.3.33 の `fail (3)` は既知の未完了判定を示す。

[一行の適用スクリプト](apply-patch.sh)は、残す 5.6.40・7.3.33 の元アーカイブで適用を確認済み。既存出力と不一致ハッシュを拒否する。7.3.33 は隔離 Linux/amd64 コンテナ内でビルドと通常 HTTP を確認した。[良性 multipart 検査](lab/check-multipart-progress.sh)はこの 2 版で `MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT` を確認した。5.6.40 は無修正版を同じラボで再ビルドし、同じ検査で `PROGRESS_PRESENT` を確認した。詳細は[版別記録](notes/php-5.6.40.md)。5.6.40 のチェックは対象 7 ファイルの SHA-256 を照合し、7.3.33 のチェックも限定的なソース条件を確認する。両方とも残る修正条件のため終了コード 3 を返す。

## 優先する未解決事項

現行の独自移植候補（5.6.40 と 7.3 系）は、通常の `memory_limit` 超過でもワーカーを `_exit(1)` で終了させる。Apache/mod_php では繰り返しのワーカー終了が可用性を損なうおそれがある。単に以前の `zend_bailout()` へ戻すと CVE-2026-109618 の危険な早期脱出が復活するため、採用しない。

7.3.33 の遅延 OOM 移植を調べ、7.3 の VM には公式 8.2 の内部巻き戻し例外がないことを確認した。VM 割り込みだけで保留 OOM を通知すると、演算結果の破棄と catch/finally の処理を安全に揃えられない。このため[実験差分](lab/candidates/php-7.3.33-delayed-oom.experimental.patch)で専用の巻き戻し状態、soft/hard limit、VM・関数呼び出し・POST終了境界、multipart・診断・デストラクタ・ストリーム出力、`debug_backtrace()` の構築中断条件を組み合わせた。機能維持候補への fuzz なし適用と変更した21ソースファイルの差分一致を確認した。Linux/amd64・Apache/mod_phpでビルドし、良性multipart・セッション・進捗の維持、通常のsoft limit超過のfatal表示と同一ワーカーの次要求処理、代表的なhard limit超過によるワーカー交代と後続要求成功を確認した。10MBの通常フォーム入力による要求起動前のsoft OOMもログへ記録され、同じワーカーが次の要求を処理した。応答本文は空であり、上限到達の証拠にはログを用いた。良性の `debug_backtrace()` と、その構築中のsoft OOM後の同一ワーカー再利用も[専用検査](lab/candidates/check-backtrace-oom.sh)で確認した。追加監査で `zend_mm_startup_ex()` の `hard_limit` 初期化漏れを修正した。更新後の fuzz なし適用、Linux/amd64 増分ビルド、通常 multipart・進捗・セッションと良性バックトレース OOM 後のワーカー再利用は通過した。別のヒープ生成経路そのものの動的実行は未確認。`ext/standard/var_unserializer.[re,c]` に保留 OOM の再帰復号・配列確保・オブジェクト構築の中断条件を追加し、fuzz なし適用と Linux/amd64 増分ビルド、通常のセッション・進捗・multipart を確認した。[良性の配列復号検査](lab/candidates/check-unserialize-oom.sh)では通常スクリプトの 8 MiB soft OOM が報告され、同じ Apache ワーカーが次の要求を処理した。`filter` 拡張の入力登録・サニタイズにも保留 OOM の中断条件を追加した。`--enable-filter` を明示した Linux/amd64 ビルドで対象2ファイルのコンパイルを確認し、Apache/mod_php の通常 GET、セッション・multipart・進捗、無害な10 MiBフォーム入力の8 MiB soft OOM後に同一ワーカーが次要求を処理することを確認した。旧版に上流の fallible allocation API はなく、大きな単一割当と upload progress 中の復号 OOM、他の拡張モジュールへの対応は未判定。**別のOOM経路、2件のCVEの全入口・異常系は未検証で、配布パッチには昇格していない。**

機能を維持する方針は、[PHP 8.2.35 の公式修正](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)と同様に、通常の上限到達を保留して VM の安全な位置で処理し、別の厳格な上限または実際の割当失敗に限ってワーカーを終了させる方式。7.3.33 の実験差分は一部を実装・良性検証したが、全境界を満たした判定ではない。5.6 には同じ VM 割り込みがなく、独立の実装が必要。対応箇所は[設計書](BACKPORT-DESIGN.md#遅延-oom-の移植境界)を参照する。

5.6.40の次の実装境界を[版別記録](notes/php-5.6.40.md)へ追加した。上限判定を持つ割当・再割当、独立した hard limit と報告時の再入防止、CALL・SWITCH・GOTO の生成 VM と関数・POST・主スクリプト終了境界を一組で扱う。CALL型VMの主ループだけに安全地点を置くと、GOTO型VMで直接分岐により迂回される。5.6の例外・スタック後始末も独立に設計する。これは未実装。

現行 5.6.40 候補の良性 `memory_limit` 超過を Linux/amd64・Apache/mod_php で確認した。接続は `curl 52` で切れ、次の要求は PID 52 から PID 62 の別ワーカーへ移った。`lab/check-normal-oom.sh` は接続断後も次の要求を確認し、ワーカー交代を診断する。soft OOM 後の同一ワーカー継続は満たしていない。

CVE-2026-109619 についても、upload progress 停止は緊急緩和にとどまる。特に 5.6.40 は [版別調査](notes/php-5.6.40.md) に記録した別の状態経路が未検証である。両 CVE は版ごとに独立して判定する。

5.6.40 の[追加候補](lab/candidates/README.md)には post-RSHUTDOWN 後の `last_error` 再消去を入れた。元アーカイブへの fuzz なし適用、隔離 Linux/amd64・Apache/mod_php のクリーンビルド、通常セッション・multipart と進捗停止は通過。最初に試した古いビルド木では進捗が有効だったため、その結果は候補検証に採用せず、新しい作業木でやり直した。後処理診断の動的確認と残る入口の網羅は未実施。

5.6.40 の[機能維持候補](lab/candidates/README.md)は upload progress の早期更新中に専用の不完全クラス復号と `Serializable` の元ペイロード再保存を行う。multipart 開始時にセッション状態を初期化し、保存先の初期化・読取失敗時に進捗更新を止める。旧版のシンボル更新は既存の進捗キーが参照値なら `progress->data` の元 `zval` を解放するため、更新先の `zval` へ進捗側のポインタを付け替えた。元ソースへの fuzz なし適用、Linux/amd64・Apache/mod_php のクリーンビルド後の増分コンパイル、通常 multipart・進捗記録・`Serializable` 値維持、参照値の結合を確認した。無効な保存先では警告が記録され、通常のアップロードと同じワーカーの後続要求が成功した。`php`・`php_binary`・`php_serialize` の3形式で良性 `Serializable` 値、multipart、進捗記録を確認した。保存形式の異常系や他のデータ型、両 CVE の全経路遮断と OOM 後の回復は未判定で、配布用パッチには昇格していない。

5.6.40 機能維持候補のファイルなし multipart 終了時に未作成の進捗データへ触れる経路を修正した。元ソースへの fuzz なし適用と Linux/amd64 増分ビルドを確認した。修正前は接続断、修正後は同じ良性投稿・既存セッションが成功し、ファイルありの進捗記録も維持した。防御全体の完了判定は変わらない。

5.6.40 機能維持候補を[並列検証用の単一差分](lab/candidates/patches/php-5.6.40.patch)として配置し、固定済み公式アーカイブから `lab/run-matrix.sh` でクリーン適用・ビルドした。結果は `pass`、`5.6.40 / apache2handler / SESSION_OK`。通常 multipart・進捗・既存セッション、3 種類の保存形式、参照値、ファイルなし投稿を確認した。結果は `/private/tmp/php-backport-56-early-candidate-results/`、パッチの SHA-256 は `0066985fbdff1b1ef8bf68a7e059d7c0eeae224411a7ed46e1dfd096faaa7979`。両 CVE の全経路遮断は未判定で、配布用 `patches/` には移していない。

公式修正にある basic/URL リライターの早期要求リセットを 5.6.40 機能維持候補へ追加した。通常 RINIT より先に動く upload progress が前要求のシリアライズ状態を再利用しないための境界である。元ソースへの fuzz なし適用、Linux/amd64 増分ビルド、3種類の保存形式での通常セッション・multipart・進捗とファイルなし投稿を確認した。異常終了後の動的な残存状態再現や全経路遮断は未判定。

7.3.33 機能維持候補にも同じ basic/URL リライター早期要求リセットを移植した。固定済み公式アーカイブの展開ソースへ fuzz なしで適用でき、続く遅延 OOM 実験差分も fuzz なしで適用できる。Linux/amd64・Apache/mod_php の増分ビルドと、通常セッション・multipart・進捗・無害な `Serializable` 値維持を確認した。生成済み `var_unserializer.c` のビルド木とパッチ結果の差は re2c の版表示と `#line` 指示だけで、他の27ファイルは一致した。異常終了後の残存状態と両 CVE の全経路は未判定。

二段差分を統合した[7.3.33実験候補](lab/candidates/patches/php-7.3.33.patch)を固定済み公式アーカイブから `lab/run-matrix.sh` でクリーン適用・ビルドした。結果は `pass`、`7.3.33 / apache2handler / SESSION_OK`、通常 multipart・進捗・`Serializable` 値維持。別の良性検査で通常 soft OOM と配列復号中の soft OOM を報告し、同じ Apache ワーカーが次要求を処理した。結果は `/private/tmp/php-backport-73-early-stack-results/`、ビルドした `libphp7.so` の SHA-256 は `7f6e3be92014a331be970df76481a4e54cece9f0b987b2ddfa7e776827941637`。両 CVE の全入口や他の拡張・保存形式は未判定で、配布用 `patches/` には移していない。

同候補の `ext/json/json_encoder.c` に、遅延 OOM を `JSON_PARTIAL_OUTPUT_ON_ERROR` で握りつぶさず中断する判定を追加した。ラボの `--disable-all` では JSON がビルドされないことを検査で発見し、PHP 7 系は JSON と filter を明示して再ビルドした。固定済み公式アーカイブからの fuzz なし適用、クリーンビルド、`7.3.33 / apache2handler / SESSION_OK`、通常 multipart・進捗、通常 JSON と従来の部分出力を確認した。続く文字列中断判定の増分ビルド後、配列とエスケープ文字列それぞれの良性 soft OOM 報告と同一ワーカー再利用を確認した。クリーンビルドの記録は `/private/tmp/php-backport-73-json-enabled-results/`。最終差分は元アーカイブへ fuzz なしで適用し、更新した JSON ファイルが実行済みソースと一致することを確認した。最終候補パッチ SHA-256 は `25a22464b251447c8da9e650bca1d2af77d49e39a1447dbd8bd44f5965250c36`、増分ビルド後の `libphp7.so` は `ecfb5d0e506c74a97c8499bcd30a95cf300575aea573359d935ee48b2d802eb3`。大きな単一割当向けの fallible API や他の JSON 経路は未実装で、両 CVE の全経路遮断は未判定。

7.3.33 の upload progress を機能維持で戻すには、専用の不完全クラス復号だけでなく `C:` 形式のペイロードを失わない再符号化も必要と確認した。[作業候補](lab/candidates/README.md)に旧版 API へ合わせた差分と良性のセッション保存検査を置いた。元アーカイブへの fuzz なし適用、Linux/amd64・Apache/mod_php でのビルドと起動、通常の multipart・upload progress、無害な `Serializable` 値の維持は通過。OOM 後の挙動と防御効果は未検証であり、配布用 `patches/` には移していない。

同候補の `main/main.c` に、公式 8.2.35 の終了境界に合わせた post-RSHUTDOWN 後の `last_error` 再消去を追加した。元ソースへの fuzz なし dry-run、Linux/amd64 の増分コンパイル、上記の正常系再実行は通過。後処理診断の動的な経路確認と CVE-2026-109619 全入口の遮断は未実施。

## 次の作業

1. PHP 5.6.40 と 7.3.33 の独自移植を先に完了する。7.3.33 実験差分を公式修正の残る保留OOM入口・例外・hard limit・要求寿命へ照合し、正常機能を確認する。5.6.40 は 7.3.33 と VM 経路が異なるため独立して実装する。
2. 両版で CVE-2026-109619 の残存経路と upload progress を含む正常機能を判定し、[検証ラボ](lab/README.md)の Linux/amd64・Apache/mod_php で良性の上限到達後のワーカー再利用と次の通常リクエストを確認する。攻撃コードや PoC は作成・実行しない。
3. 両版の実装と判定が終わってから、他の PHP 5〜7 系列の最終 `x.y.z` を版別に調査・移植・検証する。未確認範囲は公開資料に残す。

別作業の Podman VM `staticwebos-build` が自然に停止した後、`php-backport-lab` を起動して 7.3.33 候補を検証した。別作業のVMとコンテナは変更していない。候補の結果は `/private/tmp/php-backport-candidate-73/results/patch/7.3.33/` に保存した。`pass` は上記の正常系に限り、両 CVE の遮断判定ではない。

## 参照先

- [設計と版別状態](BACKPORT-DESIGN.md)
- [配布上の注意と適用手順](README.md)
- [暫定緩和と監視](DEFENSE-GUIDE.md)
- [検証ラボと結果の読み方](lab/README.md)
- [5.6.40 の版別調査](notes/php-5.6.40.md)
