# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-22（日本時間）

## 現在の状態

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（要求間に残る状態）について、公式修正を PHP 5〜7 の最終 `x.y.z` へ移植する作業を扱う。**両件の全経路遮断を確認した版はまだない。** PHP 8.0/8.1 などの公式配布物は同梱しない。旧版の正常機能を維持し、攻撃コード・PoC を作成または実行しない。

| 版 | 実装・検証済みの範囲 | 残る作業 |
| --- | --- | --- |
| 5.6.40 | 機能維持候補を元アーカイブへ fuzz なし適用し、Linux/amd64・Apache/mod_php でクリーンビルド。通常のセッション、multipart、upload progress、3 保存形式、参照値、ファイルなし投稿を確認 | 通常 soft OOM 後はワーカーが終了する。遅延 OOM と全入口の状態消去、両 CVE の遮断は未完了 |
| 7.3.33 | 統合候補に遅延 OOM、JSON 中断、`str_repeat`・`str_pad` 用の割当前 soft-limit 判定を実装。Linux/amd64・Apache/mod_php でクリーンビルド、通常のセッション・multipart・進捗・JSON・両文字列関数と、代表的な良性 OOM 後の同一ワーカー再利用を確認 | 他の大型割当・再割当・拡張、upload progress 中の復号 OOM、両 CVE の全経路は未判定 |
| 5.0.5〜5.5.38、7.0.33〜7.2.34、7.4.33 | 対象版の調査・一部の元アーカイブ固定のみ | 5.6.40 と 7.3.33 の完了後に版別移植・検証 |

`patches/` は配布用、`lab/candidates/patches/` は作業候補。候補の `pass` は実施した正常系と良性 OOM の成功だけを意味する。配布用パッチへの昇格や本番導入の承認ではない。5.6.40 と 7.3.33 の配布用 `checks/` は既知の未完了条件により終了コード 3 を返す。

## 最新の検証

7.3.33 統合候補の SHA-256 は `288d16623d3997746a5a24d3e9f3323cf82e1e28918320a75f9f24e79b131e22`。固定済み元アーカイブへ fuzz なしで適用し、`lab/run-matrix.sh` で JSON/filter を含むクリーンビルドと Apache/mod_php の検査を通過した。`libphp7.so` の SHA-256 は `bf2e850860f12add0bd9f4b21d7c7ebed46c065715f93af3b6006248fb32ad39`。結果は `/private/tmp/php-backport-pad-matrix/`。

`str_repeat`・`str_pad` の失敗可能割当は、公式修正と同様に `heap->fallible` を呼出し中だけ立て、soft limit 超過を実割当前に `NULL` として返す。通常の非 fallible 割当は従来の遅延 OOM・hard limit の経路を使う。通常の小さい繰り返しとパディング、大きな単一割当、保持中データとの合計による上限到達を確認した。OOM を報告した要求は中断し、同じ Apache ワーカーが次要求を処理した。独立の読み取りレビューで指摘された「OOM 後も要求が続く場合」を見逃す検査の穴は修正して再実行した。レビューは全経路の保証ではない。

5.6.40 の機能維持候補は `/private/tmp/php-backport-56-early-candidate-results/` で正常系を確認した。現行の配布用緊急パッチは upload progress 停止による暫定緩和であり、機能維持候補や公式同等修正と混同しない。通常 soft OOM では `curl 52` とワーカー交代を確認しており、5.6.40 を完了扱いにしない。

## 次の作業

1. 7.3.33 の残る公式修正入口、別の大型割当・再割当・拡張、異常終了後の状態寿命を調査し、良性検査を最小限追加する。特に upload progress 中の復号 OOM と要求間状態を判定する。
2. 5.6.40 の VM 構造に合わせた遅延 OOM と状態消去を独立して実装し、Linux/amd64・Apache/mod_php で検証する。通常 session と upload progress の機能を維持する。
3. **この 2 版の実装と判定が終わってから**、他の PHP 5〜7 系列の最終 `x.y.z` に進む。版ごとに公式修正との機能同等性と未検証範囲を記録する。

検証VMは作業終了時に `podman machine stop php-backport-lab` で正常停止する。別作業の `staticwebos-build` VMは変更しない。

## 参照先

- [設計と版別状態](BACKPORT-DESIGN.md)
- [候補の説明](lab/candidates/README.md)
- [検証ラボ](lab/README.md)
- [5.6.40 の版別調査](notes/php-5.6.40.md)
- [前回までの詳細記録](archive/HANDOFF-2026-10-22-before-fallible.md)
