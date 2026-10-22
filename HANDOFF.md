# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-22（日本時間）

## 現在の状態

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（要求間に残る状態）について、公式修正を PHP 5〜7 の最終 `x.y.z` へ移植する作業を扱う。**両件の全経路遮断を確認した版はまだない。** PHP 8.0/8.1 などの公式配布物は同梱しない。旧版の正常機能を維持し、攻撃コード・PoC を作成または実行しない。

| 版 | 実装・検証済みの範囲 | 残る作業 |
| --- | --- | --- |
| 5.6.40 | 機能維持候補を元アーカイブへ fuzz なし適用し、Linux/amd64・Apache/mod_php でクリーンビルド。割当上限の減算判定を追加して増分ビルドし、通常のセッション、multipart、upload progress、3 保存形式、参照値、ファイルなし投稿を再確認 | 通常 soft OOM 後はワーカーが終了する。遅延 OOM と全入口の状態消去、両 CVE の遮断は未完了 |
| 7.3.33 | 統合候補に遅延 OOM、JSON 中断、主要文字列関数の失敗可能割当、`explode` と upload progress の OOM 保留確認を実装。保存モジュール失敗境界と multipart 終了時の配列分離後のポインタ再取得まで含めて増分ビルド。3 保存形式を含む正常系と代表的な良性 OOM 後の同一ワーカー再利用を確認 | 最新差分全体の再クリーンビルド、配列分離後のポインタ更新箇所を狙った動的確認、他の大型割当・再割当・拡張、upload progress 中の OOM 発生地点、両 CVE の全経路は未判定 |
| 5.0.5〜5.5.38、7.0.33〜7.2.34、7.4.33 | 対象版の調査・一部の元アーカイブ固定のみ | 5.6.40 と 7.3.33 の完了後に版別移植・検証 |

`patches/` は配布用、`lab/candidates/patches/` は作業候補。候補の `pass` は実施した正常系と良性 OOM の成功だけを意味する。配布用パッチへの昇格や本番導入の承認ではない。5.6.40 と 7.3.33 の配布用 `checks/` は既知の未完了条件により終了コード 3 を返す。

## 最新の検証

7.3.33 統合候補の最新差分 SHA-256 は `8e22b13a260f51f9295c585a1483677abaf78832259b978deeeccae89af8652b`。セッション復号・読込・GC 中の保留 OOM に加え、保存モジュールの open・ID生成・read が失敗した場合も保留 OOM 中の追加処理を止める。multipart 終了時には `progress->data` の配列分離・更新後に `bytes_processed` のバケットを引き直す。直前の復号中断までを含む差分は `/private/tmp/php-backport-73-decode-oom-clean/patch/7.3.33/` で固定済み元アーカイブへの fuzz なし適用、Linux/amd64 クリーンビルド、Apache/mod_php 版別チェックが `pass`。現行差分は fuzz なし dry-run、増分ビルドと同じ版別チェックを通過した。現行 `libphp7.so` の SHA-256 は `b92f00230db4e083259b450af5e4ec6b9a939f50efb519be370fdba5ed1a8135`。ポインタ更新箇所を直接狙った検査、OOM の厳密な発生地点と全入口・全拡張の遮断は未確認。

`str_repeat`・`str_pad`・`implode`・`chunk_split`・`wordwrap` の失敗可能割当は、`heap->fallible` を呼出し中だけ立て、soft limit 超過を実割当前に `NULL` として返す。`wordwrap` の途中の拡張・縮小も失敗可能な再割当へ変更し、失敗時に元の文字列を解放する。通常の非 fallible 割当は従来の遅延 OOM・hard limit の経路を使う。通常の文字列処理と `wordwrap` の旧版の引数エラー、結果拡張時の上限到達を確認した。OOM を報告した要求は中断し、同じ Apache ワーカーが次要求を処理した。拡張・縮小の割当失敗を個別に発生させる動的検査は未実施。

`explode` は正の `limit` の結果生成ループと末尾挿入、負の `limit` の位置収集・結果生成ループで保留 OOM を検査する。通常の正負 `limit`、旧版の `limit=1`、64 件を超える位置収集、入力準備後の正 `limit` 終端を含む良性 soft OOM と同一ワーカー再利用を確認した。末尾挿入の抑止はソース上の条件でも確認した。

`php_session_rfc1867_update()` と cleanup はセッション再読込や配列分離後の保留 OOM を検査し、保留中の進捗更新・保存を止めて更新フラグを解除する。フォーム・ファイルイベントの割当後は保留 OOM を確認して後続処理を止め、multipart 終了時も保留 OOM のまま進捗配列を分離・更新しない。元アーカイブへの fuzz なし実適用、Linux/amd64・Apache/mod_php の増分ビルド、通常の upload progress を確認した。大きな通常セッションを保存し小さい `memory_limit` で multipart を送る良性検査では、メモリ上限エラー、アプリスクリプト非実行、同一ワーカー再利用を確認した。OOM の厳密な発生地点と、全ての状態寿命・復号失敗経路は未確認。

5.6.40 の機能維持候補は `/private/tmp/php-backport-56-early-candidate-results/` で正常系を確認した。候補パッチ SHA-256 は `f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f`、増分ビルド後の `libphp5.so` は `95486dab9f2e1d47f38e297fed60ea106ff2b55034ad619c6de32cb9cb8b9828`。配布用緊急パッチ SHA-256 は `2eb8b5ba1cb8cc76516d91afc5d341c1144db3c9e1f14301b5722fe5fa124e6b`。両パッチの元ソースへの fuzz なし dry-run は通過したが、変更後の配布用パッチ全体の再ビルドは未実施。配布用は upload progress 停止による暫定緩和であり、機能維持候補や公式同等修正と混同しない。通常 soft OOM では `curl 52` とワーカー交代を確認しており、5.6.40 を完了扱いにしない。

## 次の作業

1. 7.3.33 の残る公式修正入口、別の大型割当・再割当・拡張、異常終了後の状態寿命を調査し、良性検査を最小限追加する。特に upload progress 中の復号 OOM と要求間状態を判定する。
2. 5.6.40 は allocator の soft/hard 上限だけでなく、生成 VM の CALL/SWITCH/GOTO、POST・入力登録、関数呼出し、主スクリプトの境界を結合して遅延 OOM と状態消去を実装する。Linux/amd64・Apache/mod_php で通常 session と upload progress の機能を維持して検証する。
3. **この 2 版の実装と判定が終わってから**、他の PHP 5〜7 系列の最終 `x.y.z` に進む。版ごとに公式修正との機能同等性と未検証範囲を記録する。

検証VMは作業終了時に `podman machine stop php-backport-lab` で正常停止する。別作業の `staticwebos-build` VMは変更しない。

GitHub への次回 push は保留。新しい eMudhra CA 信頼禁止規定について Git HTTPS の実際の検証経路で拒否を確認できず、GitHub SSH は `Permission denied (publickey)` だった。ローカルの変更は保持し、証明書検証または SSH 認証を満たす経路で送信する。

## 参照先

- [設計と版別状態](BACKPORT-DESIGN.md)
- [候補の説明](lab/candidates/README.md)
- [検証ラボ](lab/README.md)
- [5.6.40 の版別調査](notes/php-5.6.40.md)
- [前回までの詳細記録](archive/HANDOFF-2026-10-22-before-fallible.md)
