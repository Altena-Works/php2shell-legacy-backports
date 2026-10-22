# PHP 旧版の作業候補

ここにあるパッチは公式修正を旧版へ移す**開発中の候補**です。`patches/` の配布用パッチとして導入しないでください。CVE-2026-109618 / CVE-2026-109619 の全経路遮断は、どの版でも未確認です。

| 版 | 現行候補 | 確認済み | 未完了 |
| --- | --- | --- | --- |
| 7.3.33 | [統合パッチ](patches/php-7.3.33.patch) (`9483d9981e0fdee977d06c0633ce82eb149f36b1a63c8e32a74ae0bd2419b6bd`) | 固定元ソースへのfuzzなし適用。Linux/amd64・Apache/mod_phpのクリーンビルドと版別検査、intlの通常機能と良性OOM後の同一ワーカー継続。GD/WBMP個別コンパイル | IMAP・GD有効構成の実測、各内部割当の失敗地点、残る公式差分とupload progressの全要求境界など |
| 5.6.40 | [統合パッチ](patches/php-5.6.40.patch) (`f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f`) | 固定元ソースへのfuzzなし適用、先行候補のクリーンビルド、追加修正後の増分ビルドと通常セッション・multipart | 遅延OOM、soft OOM後のワーカー継続、追加修正後のクリーンビルド |

7.3.33の現候補のクリーンビルドと版別検査は `/private/tmp/php-backport-73-intl-clean/patch/7.3.33/` で `pass`。ビルドにはintlを含めました。intlの良性OOM検査は同じビルドを使って別途実行しました。IMAPは必要な開発ヘッダがなく、コンパイル・実動作は未検証です。GD/WBMPは個別コンパイルのみ確認しました。

```bash
bash lab/run-matrix.sh --versions 7.3.33 --jobs 1 \
  --patch-dir "$PWD/lab/candidates/patches" \
  --check-dir "$PWD/lab/candidates/checks" \
  --results-dir /private/tmp/php-backport-check
```

実行には、[検証ラボ](../README.md)に記載したローカルVM、固定した元アーカイブ、ビルダーが必要です。既存の結果と混ざらない `--results-dir` を指定してください。版別の残課題と先行候補の検査履歴は[HANDOFF](../../HANDOFF.md)と[検証履歴](../../archive/HANDOFF-2026-10-22-path-verification.md)を参照してください。
