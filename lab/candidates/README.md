# PHP 旧版の作業候補

ここにあるパッチは公式修正を旧版へ移す**開発中の候補**です。`patches/` の配布用パッチとして導入しないでください。CVE-2026-109618 / CVE-2026-109619 の全経路遮断は、どの版でも未確認です。

| 版 | 現行候補 | 確認済み | 未完了 |
| --- | --- | --- | --- |
| 7.3.33 | [統合パッチ](patches/php-7.3.33.patch) (`a3bc4061fa7186980400220cdba03fa0e6e102a6a217aba71a50dd0f1a79fa6f`) | 固定元ソースへのfuzzなし適用、Linux x86_64・Apache/mod_phpのクリーンビルド、版別正常系と指定した良性OOM検査 | 残る公式差分、upload progressの全要求境界、mbstringのlibmbfl・HTTP入力経路など |
| 5.6.40 | [統合パッチ](patches/php-5.6.40.patch) (`f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f`) | 固定元ソースへのfuzzなし適用、先行候補のクリーンビルド、追加修正後の増分ビルドと通常セッション・multipart | 遅延OOM、soft OOM後のワーカー継続、追加修正後のクリーンビルド |

7.3.33の最新のクリーンビルドと版別検査の記録は `/private/tmp/php-backport-73-mbstring-clean/patch/7.3.33/`。この実測では通常のmbstring入力変換・文字コード変換・正規表現置換、ならびに低メモリ下での良性入力変換と通常置換のOOM報告・同一ワーカー継続も確認しました。個々の確保失敗地点や未搭載拡張まで確認した結果ではありません。

```bash
bash lab/run-matrix.sh --versions 7.3.33 --jobs 1 \
  --patch-dir "$PWD/lab/candidates/patches" \
  --check-dir "$PWD/lab/candidates/checks" \
  --results-dir /private/tmp/php-backport-check
```

実行には、[検証ラボ](../README.md)に記載したローカルVM、固定した元アーカイブ、ビルダーが必要です。既存の結果と混ざらない `--results-dir` を指定してください。版別の残課題と先行候補の検査履歴は[HANDOFF](../../HANDOFF.md)と[検証履歴](../../archive/HANDOFF-2026-10-22-path-verification.md)を参照してください。
