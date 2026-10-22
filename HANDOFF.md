# PHP 旧版バックポート 引き継ぎ

更新日：2026-10-22（日本時間）

## 現在の状態

このリポジトリは CVE-2026-109618（OOM 時の不完全な状態）と CVE-2026-109619（要求間に残る状態）について、公式修正を PHP 5〜7 の最終 `x.y.z` へ移植する作業を扱う。**両件の全経路遮断を確認した版はまだない。** PHP 8.0/8.1 などの公式配布物は同梱しない。旧版の正常機能を維持し、攻撃コード・PoC を作成または実行しない。

PHP 8.5.12 の二重解放報告は、報告者が当日修正された2件とは別の問題と追記した。原因箇所・再現条件は非公開で、旧版への該当性と現候補の遮断可否は未確認。詳細は[遮断範囲の監査](notes/coverage-audit-2026-10-22.md)。

公式8.2.34→8.2.35のOOM・要求境界に関連する追加行を調べた当初、7.3.33候補に変更がないファイルは48件あった。うち46件は7.3.33にも存在し、2件は存在しない。現在は `shmop_read`、Cookie、ファイル・画像処理、JSONパーサの一部などを移植・検証した。版間の違いを個別判定する必要があり、正式版公開に必要な全経路遮断の証拠は揃っていない。詳細は[遮断範囲の監査](notes/coverage-audit-2026-10-22.md)。

| 版 | 実装・検証済みの範囲 | 残る作業 |
| --- | --- | --- |
| 5.6.40 | 機能維持候補を元アーカイブへ fuzz なし適用し、Linux/amd64・Apache/mod_php でクリーンビルド。割当上限の減算判定を追加して増分ビルドし、通常のセッション、multipart、upload progress、3 保存形式、参照値、ファイルなし投稿を再確認 | 通常 soft OOM 後はワーカーが終了する。遅延 OOM と全入口の状態消去、両 CVE の遮断は未完了 |
| 7.3.33 | 現行候補を固定済み元ソースへ fuzz なし適用し、Linux/amd64 クリーンビルドと Apache/mod_php 版別正常系・良性OOM検査を通過。`nl2br`・`unpack`・`shmop_read`・Cookie・HTML・`preg_replace` の指定経路を検査。`file()`・`fgets`・CSV・XBM・JSON復号、許可クラスと長いキーの `unserialize` 正常系、`levenshtein` の旧版仕様を確認 | 他の大型割当・再割当・拡張、upload progress 中の OOM 発生地点、両 CVE の全経路は未判定 |
| 5.0.5〜5.5.38、7.0.33〜7.2.34、7.4.33 | 対象版の調査・一部の元アーカイブ固定のみ | 5.6.40 と 7.3.33 の完了後に版別移植・検証 |

`patches/` は配布用、`lab/candidates/patches/` は作業候補。候補の `pass` は実施した正常系と良性 OOM の成功だけを意味する。配布用パッチへの昇格や本番導入の承認ではない。5.6.40 と 7.3.33 の配布用 `checks/` は既知の未完了条件により終了コード 3 を返す。

## 最新の検証

7.3.33 の `ext/pcre/php_pcre.c` で `preg_replace` とコールバック置換の結果バッファ確保・再確保を失敗可能にし、失敗時に保有バッファを解放して解析を中断する。コールバック引数構築中の保留OOMも関数呼出し前に中断する。現行候補 SHA-256 は `444defa3d4e06eaf07d469b10f6c2d555229ff4b6246043e00d9d7e102eb0cfe`。`/private/tmp/php-backport-73-pcre-callback-clean/patch/7.3.33/` で元ソースへの fuzz なし適用、Linux/amd64 クリーンビルド、Apache/mod_php 版別チェックが `pass`。生成 `libphp7.so` SHA-256 は `181bc3c0cce4f39aa77a12c8562aeba01621945a29646e78d1f7003b0d1c4411`。通常の `preg_replace`・コールバック置換と、大きな正常入力による良性 OOM 後の同一ワーカー継続を確認した。PCRE のマッチ・分割、コールバック処理中の各 OOM 発生地点、各再確保地点の個別失敗は未判定。

同じクリーンビルドで、通常セッション・multipart・upload progress、3保存形式、JSON復号と良性OOM、`unserialize` の許可クラス・長いキー、ファイル・画像・文字列・配列の既存チェック、セッション復号OOM後の同一ワーカー継続を確認した。これは指定経路の結果であり、両CVEの全入口・要求間状態の遮断証明ではない。先行候補ごとのハッシュ、失敗地点と検査内容は[個別経路の検証履歴](archive/HANDOFF-2026-10-22-path-verification.md)に移した。

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
