# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-22（日本時間）

## 現在の成果物と判定

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（リクエスト間に残る状態）について、公式バックポートがない PHP 5〜7 への独自移植を扱う。**両件を完全に遮断した版は、現時点の記録にはない。** PHP 7.4、8.0、8.1 向けの公式最小バックポートは同梱せず、公式配布元を参照する。

| 版 | 記録されている到達点 | 残る判定 |
| --- | --- | --- |
| 5.6.40 | 緊急候補を作成。Linux/amd64・Apache/mod_php の通常セッション・multipart、upload progress 停止、修正後 7 ファイルのハッシュ照合を確認 | CVE-2026-109619 の別経路、OOM 後のワーカー回復、完全な機能維持は未確認 |
| 7.3.33 | 機能維持候補に遅延OOM実験差分を重ね、Apache/mod_phpの通常セッション・multipart・進捗、良性soft OOM後の同一ワーカー再利用と代表的なhard limit超過後のワーカー交代を確認 | 別のOOM経路・両件の完全遮断は未実証 |
| 5.0.5 / 5.1.6 / 5.2.17 / 5.3.29 | 公式アーカイブの SHA-256 を固定。session ソースに upload progress シンボルなし | OOM と他の要求間状態、実行動作は未判定 |
| 5.4.45 / 5.5.38 / 7.0.33 / 7.1.33 / 7.2.34 | 対応パッチは未完成 | 導入対象外 |

7.3.29 は同じ 7.3 系列の最終版ではないため、候補パッチ・検査・ハッシュを配布物から除いた。7.4.33、8.0.30、8.1.34 の公式差分と版専用の検査・記録も配布物から除いた。[README](README.md) は独自移植だけを検証候補として示す。5.6.40 と 7.3.33 の `fail (3)` は既知の未完了判定を示す。

[一行の適用スクリプト](apply-patch.sh)は、残す 5.6.40・7.3.33 の元アーカイブで適用を確認済み。既存出力と不一致ハッシュを拒否する。7.3.33 は隔離 Linux/amd64 コンテナ内でビルドと通常 HTTP を確認した。[良性 multipart 検査](lab/check-multipart-progress.sh)はこの 2 版で `MULTIPART_OK / SESSION_OK / PROGRESS_ABSENT` を確認した。5.6.40 は無修正版を同じラボで再ビルドし、同じ検査で `PROGRESS_PRESENT` を確認した。詳細は[版別記録](notes/php-5.6.40.md)。5.6.40 のチェックは対象 7 ファイルの SHA-256 を照合し、7.3.33 のチェックも限定的なソース条件を確認する。両方とも残る修正条件のため終了コード 3 を返す。

## 優先する未解決事項

現行の独自移植候補（5.6.40 と 7.3 系）は、通常の `memory_limit` 超過でもワーカーを `_exit(1)` で終了させる。Apache/mod_php では繰り返しのワーカー終了が可用性を損なうおそれがある。単に以前の `zend_bailout()` へ戻すと CVE-2026-109618 の危険な早期脱出が復活するため、採用しない。

7.3.33 の遅延 OOM 移植を調べ、7.3 の VM には公式 8.2 の内部巻き戻し例外がないことを確認した。VM 割り込みだけで保留 OOM を通知すると、演算結果の破棄と catch/finally の処理を安全に揃えられない。このため[実験差分](lab/candidates/php-7.3.33-delayed-oom.experimental.patch)で専用の巻き戻し状態、soft/hard limit、VM・関数呼び出し・POST終了境界、multipart・診断・デストラクタ・ストリーム出力、`debug_backtrace()` の構築中断条件を組み合わせた。機能維持候補への fuzz なし適用と変更した21ソースファイルの差分一致を確認した。Linux/amd64・Apache/mod_phpでビルドし、良性multipart・セッション・進捗の維持、通常のsoft limit超過のfatal表示と同一ワーカーの次要求処理、代表的なhard limit超過によるワーカー交代と後続要求成功を確認した。10MBの通常フォーム入力による要求起動前のsoft OOMもログへ記録され、同じワーカーが次の要求を処理した。応答本文は空であり、上限到達の証拠にはログを用いた。良性の `debug_backtrace()` と、その構築中のsoft OOM後の同一ワーカー再利用も[専用検査](lab/candidates/check-backtrace-oom.sh)で確認した。追加監査で `zend_mm_startup_ex()` の `hard_limit` 初期化漏れを修正した。更新後の fuzz なし適用、Linux/amd64 増分ビルド、通常 multipart・進捗・セッションと良性バックトレース OOM 後のワーカー再利用は通過した。別のヒープ生成経路そのものの動的実行は未確認。`ext/standard/var_unserializer.[re,c]` に保留 OOM の再帰復号・配列確保・オブジェクト構築の中断条件を追加し、fuzz なし適用と Linux/amd64 増分ビルド、通常のセッション・進捗・multipart を確認した。[良性の配列復号検査](lab/candidates/check-unserialize-oom.sh)では通常スクリプトの 8 MiB soft OOM が報告され、同じ Apache ワーカーが次の要求を処理した。`filter` 拡張の入力登録・サニタイズにも保留 OOM の中断条件を追加した。`--enable-filter` を明示した Linux/amd64 ビルドで対象2ファイルのコンパイルを確認し、Apache/mod_php の通常 GET、セッション・multipart・進捗、無害な10 MiBフォーム入力の8 MiB soft OOM後に同一ワーカーが次要求を処理することを確認した。旧版に上流の fallible allocation API はなく、大きな単一割当と upload progress 中の復号 OOM、他の拡張モジュールへの対応は未判定。**別のOOM経路、2件のCVEの全入口・異常系は未検証で、配布パッチには昇格していない。**

機能を維持する方針は、[PHP 8.2.35 の公式修正](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)と同様に、通常の上限到達を保留して VM の安全な位置で処理し、別の厳格な上限または実際の割当失敗に限ってワーカーを終了させる方式。7.3.33 の実験差分は一部を実装・良性検証したが、全境界を満たした判定ではない。5.6 には同じ VM 割り込みがなく、独立の実装が必要。対応箇所は[設計書](BACKPORT-DESIGN.md#遅延-oom-の移植境界)を参照する。

5.6.40の次の実装境界を[版別記録](notes/php-5.6.40.md)へ追加した。CALL型VMの主ループだけに安全地点を置くと、生成器が出力できるGOTO型VMで直接分岐により迂回される。生成テンプレートと生成器を含めて配送地点を揃え、5.6の例外・スタック後始末を独立に設計する。これは未実装。

CVE-2026-109619 についても、upload progress 停止は緊急緩和にとどまる。特に 5.6.40 は [版別調査](notes/php-5.6.40.md) に記録した別の状態経路が未検証である。両 CVE は版ごとに独立して判定する。

5.6.40 の[追加候補](lab/candidates/README.md)には post-RSHUTDOWN 後の `last_error` 再消去を入れた。元アーカイブへの fuzz なし適用、隔離 Linux/amd64・Apache/mod_php のクリーンビルド、通常セッション・multipart と進捗停止は通過。最初に試した古いビルド木では進捗が有効だったため、その結果は候補検証に採用せず、新しい作業木でやり直した。後処理診断の動的確認と残る入口の網羅は未実施。

5.6.40 の[機能維持候補](lab/candidates/README.md)は upload progress の早期更新中に専用の不完全クラス復号と `Serializable` の元ペイロード再保存を行う。multipart 開始時にセッション状態を初期化し、保存先の初期化・読取失敗時に進捗更新を止める。旧版のシンボル更新は既存の進捗キーが参照値なら `progress->data` の元 `zval` を解放するため、更新先の `zval` へ進捗側のポインタを付け替えた。元ソースへの fuzz なし適用、Linux/amd64・Apache/mod_php のクリーンビルド後の増分コンパイル、通常 multipart・進捗記録・`Serializable` 値維持、参照値の結合を確認した。無効な保存先では警告が記録され、通常のアップロードと同じワーカーの後続要求が成功した。`php`・`php_binary`・`php_serialize` の3形式で良性 `Serializable` 値、multipart、進捗記録を確認した。保存形式の異常系や他のデータ型、両 CVE の全経路遮断と OOM 後の回復は未判定で、配布用パッチには昇格していない。

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
