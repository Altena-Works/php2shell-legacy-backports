# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-22（日本時間）

## 現在の状態

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（要求間に残る状態）について、公式修正を PHP 5〜7 の最終 `x.y.z` へ移植する作業を扱う。**両件の全経路遮断を確認した版はまだない。** PHP 8.0/8.1 などの公式配布物は同梱しない。旧版の正常機能を維持し、攻撃コード・PoC を作成または実行しない。

PHP 8.5.12 の二重解放報告は、報告者が当日修正された2件とは別の問題と追記した。原因箇所・再現条件は非公開で、旧版への該当性と現候補の遮断可否は未確認。詳細は[遮断範囲の監査](notes/coverage-audit-2026-10-22.md)。

公式8.2.34→8.2.35のOOM・要求境界に関連する追加行を調べたところ、7.3.33候補に変更がないファイルが48件あった。うち46件は7.3.33にも存在し、2件は存在しない。版間の違いを個別判定する必要があり、正式版公開に必要な全経路遮断の証拠は揃っていない。詳細は[遮断範囲の監査](notes/coverage-audit-2026-10-22.md)。

| 版 | 実装・検証済みの範囲 | 残る作業 |
| --- | --- | --- |
| 5.6.40 | 機能維持候補を元アーカイブへ fuzz なし適用し、Linux/amd64・Apache/mod_php でクリーンビルド。割当上限の減算判定を追加して増分ビルドし、通常のセッション、multipart、upload progress、3 保存形式、参照値、ファイルなし投稿を再確認 | 通常 soft OOM 後はワーカーが終了する。遅延 OOM と全入口の状態消去、両 CVE の遮断は未完了 |
| 7.3.33 | 現行候補を固定済み元ソースへ fuzz なし適用し、Linux/amd64 クリーンビルドと Apache/mod_php 版別正常系・良性OOM検査を通過。`nl2br` の大型結果割当も確認 | 他の大型割当・再割当・拡張、upload progress 中の OOM 発生地点、両 CVE の全経路は未判定 |
| 5.0.5〜5.5.38、7.0.33〜7.2.34、7.4.33 | 対象版の調査・一部の元アーカイブ固定のみ | 5.6.40 と 7.3.33 の完了後に版別移植・検証 |

`patches/` は配布用、`lab/candidates/patches/` は作業候補。候補の `pass` は実施した正常系と良性 OOM の成功だけを意味する。配布用パッチへの昇格や本番導入の承認ではない。5.6.40 と 7.3.33 の配布用 `checks/` は既知の未完了条件により終了コード 3 を返す。

## 最新の検証

7.3.33 統合候補の現行差分 SHA-256 は `d10830031d6ef61026669e7a5eb1f3d07afc8a3f62b3358f9bd81cdb92e9947f`。`/private/tmp/php-backport-73-nl2br-clean/patch/7.3.33/` で固定済み元ソースへの fuzz なし適用、Linux/amd64 クリーンビルド、Apache/mod_php 版別チェックが `pass`。生成した `libphp7.so` の SHA-256 は `60eceb1588a839bc16db7476fee6bdd080a24fb15b2388f0cfcf6c8689808c91`。3保存形式の通常セッション・multipart進捗、JSON、`array_chunk`・`array_map`・`array_pad`・`php://memory`・`nl2br` の正常系と良性OOM、upload progress 中のセッション復号OOM後の同一ワーカー継続を確認した。**これらは指定構成・指定経路の検証であり、全入口・全拡張の遮断証明ではない。**

`str_repeat`・`str_pad`・`implode`・`chunk_split`・`wordwrap` の失敗可能割当は、`heap->fallible` を呼出し中だけ立て、soft limit 超過を実割当前に `NULL` として返す。`wordwrap` の途中の拡張・縮小も失敗可能な再割当へ変更し、失敗時に元の文字列を解放する。通常の非 fallible 割当は従来の遅延 OOM・hard limit の経路を使う。通常の文字列処理と `wordwrap` の旧版の引数エラー、結果拡張時の上限到達を確認した。OOM を報告した要求は中断し、同じ Apache ワーカーが次要求を処理した。拡張・縮小の割当失敗を個別に発生させる動的検査は未実施。

`explode` は正の `limit` の結果生成ループと末尾挿入、負の `limit` の位置収集・結果生成ループで保留 OOM を検査する。通常の正負 `limit`、旧版の `limit=1`、64 件を超える位置収集、入力準備後の正 `limit` 終端を含む良性 soft OOM と同一ワーカー再利用を確認した。末尾挿入の抑止はソース上の条件でも確認した。

`php_session_rfc1867_update()` と cleanup はセッション再読込や配列分離後の保留 OOM を検査し、保留中の進捗更新・保存を止めて更新フラグを解除する。フォーム・ファイルイベントの割当後は保留 OOM を確認して後続処理を止め、multipart 終了時も保留 OOM のまま進捗配列を分離・更新しない。元アーカイブへの fuzz なし実適用、Linux/amd64・Apache/mod_php の増分ビルド、通常の upload progress を確認した。大きな通常セッションを保存し小さい `memory_limit` で multipart を送る良性検査では、メモリ上限エラー、アプリスクリプト非実行、同一ワーカー再利用を確認した。OOM の厳密な発生地点と、全ての状態寿命・復号失敗経路は未確認。

5.6.40 の機能維持候補は `/private/tmp/php-backport-56-early-candidate-results/` で正常系を確認した。候補パッチ SHA-256 は `f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f`、増分ビルド後の `libphp5.so` は `95486dab9f2e1d47f38e297fed60ea106ff2b55034ad619c6de32cb9cb8b9828`。配布用緊急パッチ SHA-256 は `2eb8b5ba1cb8cc76516d91afc5d341c1144db3c9e1f14301b5722fe5fa124e6b`。両パッチの元ソースへの fuzz なし dry-run は通過したが、変更後の配布用パッチ全体の再ビルドは未実施。配布用は upload progress 停止による暫定緩和であり、機能維持候補や公式同等修正と混同しない。通常 soft OOM では `curl 52` とワーカー交代を確認しており、5.6.40 を完了扱いにしない。

## 次の作業

1. 7.3.33 は他の大型割当・再割当・拡張、異常終了後の状態寿命を調査する。特に upload progress 中の復号 OOM と要求間状態を判定し、公式修正に対応する未判定ファイルを一つずつ閉じる。
2. 5.6.40 は allocator の soft/hard 上限だけでなく、生成 VM の CALL/SWITCH/GOTO、POST・入力登録、関数呼出し、主スクリプトの境界を結合して遅延 OOM と状態消去を実装する。Linux/amd64・Apache/mod_php で通常 session と upload progress の機能を維持して検証する。
3. **この 2 版の実装と判定が終わってから**、他の PHP 5〜7 系列の最終 `x.y.z` に進む。版ごとに公式修正との機能同等性と未検証範囲を記録する。

ユーザーの今回の明示許可により `staticwebos-build` VM を正常停止し、`php-backport-lab` で7.3.33 クリーンビルド・検査を実施した。検証後、`php-backport-lab` は正常停止した。`staticwebos-build` はこの作業では再起動していない。

GitHub への次回 push は保留。新しい eMudhra CA 信頼禁止規定について Git HTTPS の実際の検証経路で拒否を確認できず、GitHub SSH は `Permission denied (publickey)` だった。ローカルの変更は保持し、証明書検証または SSH 認証を満たす経路で送信する。

## 参照先

- [設計と版別状態](BACKPORT-DESIGN.md)
- [候補の説明](lab/candidates/README.md)
- [検証ラボ](lab/README.md)
- [5.6.40 の版別調査](notes/php-5.6.40.md)
- [遮断範囲の監査](notes/coverage-audit-2026-10-22.md)
- [前回までの詳細記録](archive/HANDOFF-2026-10-22-before-fallible.md)
