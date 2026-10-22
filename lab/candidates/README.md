# PHP 旧版の作業候補

ここにあるパッチは公式修正を旧版へ移す**開発中の候補**です。`patches/` の配布用パッチとして導入しないでください。CVE-2026-109618 / CVE-2026-109619 の全経路遮断は、どの版でも未確認です。

| 版 | 現行候補 | 確認済み | 未完了 |
| --- | --- | --- | --- |
| 7.3.33 | [統合パッチ](patches/php-7.3.33.patch) (`044fe9c50437c0070fbbbaca59bfd5c1ec9c098c62526600308e93bacd7fa232`) | 固定元ソースへのfuzzなし適用。前候補のクリーンビルドと版別検査、追加差分の増分ビルドと通常復号・良性OOM検査 | 現候補の全体クリーンビルド、残る公式差分、upload progressの全要求境界、mbstringのHTTP入力・未判定libmbfl経路など |
| 5.6.40 | [統合パッチ](patches/php-5.6.40.patch) (`f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f`) | 固定元ソースへのfuzzなし適用、先行候補のクリーンビルド、追加修正後の増分ビルドと通常セッション・multipart | 遅延OOM、soft OOM後のワーカー継続、追加修正後のクリーンビルド |

7.3.33の前候補のクリーンビルドと版別検査の記録は `/private/tmp/php-backport-73-allowed-clean/patch/7.3.33/`。現候補の復号側追加差分はそのビルドに適用して増分検証しました。許可クラス名・キーの各割当失敗地点と、要求中のキー重複排除を使わないことによる性能影響は未実測です。

```bash
bash lab/run-matrix.sh --versions 7.3.33 --jobs 1 \
  --patch-dir "$PWD/lab/candidates/patches" \
  --check-dir "$PWD/lab/candidates/checks" \
  --results-dir /private/tmp/php-backport-check
```

実行には、[検証ラボ](../README.md)に記載したローカルVM、固定した元アーカイブ、ビルダーが必要です。既存の結果と混ざらない `--results-dir` を指定してください。版別の残課題と先行候補の検査履歴は[HANDOFF](../../HANDOFF.md)と[検証履歴](../../archive/HANDOFF-2026-10-22-path-verification.md)を参照してください。
