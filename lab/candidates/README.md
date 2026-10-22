# PHP 旧版の作業候補

ここにあるパッチは公式修正を旧版へ移す**開発中の候補**です。`patches/` の配布用パッチとして導入しないでください。CVE-2026-109618 / CVE-2026-109619 の全経路遮断は、どの版でも未確認です。

| 版 | 現行候補 | 確認済み | 未完了 |
| --- | --- | --- | --- |
| 7.3.33 | [統合パッチ](patches/php-7.3.33.patch) (`b7f35b668d465c6be2c38a4b27f0d8169a9c200c343ade27b7ea258052b3e2b9`) | 現候補の固定元ソースへのfuzzなし適用。追加前候補のLinux/amd64・Apache/mod_phpクリーンビルドと版別検査、intl・OPcache有効での通常機能と良性OOM後の同一ワーカー継続。GD/WBMP個別コンパイル | 現候補の全体クリーンビルド、bzip2・IMAP・GD有効構成の実測、各内部割当の失敗地点、残る公式差分とupload progressの全要求境界など |
| 5.6.40 | [統合パッチ](patches/php-5.6.40.patch) (`f06450a032c02f63f3375f2abd803fd647b1b0614621812dbe2a43255d632e9f`) | 固定元ソースへのfuzzなし適用、先行候補のクリーンビルド、追加修正後の増分ビルドと通常セッション・multipart | 遅延OOM、soft OOM後のワーカー継続、追加修正後のクリーンビルド |

7.3.33の追加前候補のクリーンビルドと版別検査は `/private/tmp/php-backport-73-opcache-clean/patch/7.3.33/` で `pass`。ビルドにはintlとOPcacheを含めました。版別検査にはintlの良性OOMと、OPcache有効時の通常セッション・multipartおよび良性OOM後の同一ワーカー継続を含めました。IMAPは必要な開発ヘッダがなく、コンパイル・実動作は未検証です。GD/WBMPは個別コンパイルのみ確認しました。bzip2は今回候補へ追加しfuzzなし適用を確認しましたが、Linux/amd64の構文・型検査のみ通過し、bzip2有効のリンク・Apache実動作は未検証です。現候補の `mbfl_strcut()` 追加差分は増分ビルド、ASCII・日本語ISO-2022-JPの通常動作と良性OOM後の同一ワーカー継続を通過しました。

```bash
bash lab/run-matrix.sh --versions 7.3.33 --jobs 1 \
  --patch-dir "$PWD/lab/candidates/patches" \
  --check-dir "$PWD/lab/candidates/checks" \
  --results-dir /private/tmp/php-backport-check
```

実行には、[検証ラボ](../README.md)に記載したローカルVM、固定した元アーカイブ、ビルダーが必要です。既存の結果と混ざらない `--results-dir` を指定してください。版別の残課題と先行候補の検査履歴は[HANDOFF](../../HANDOFF.md)と[検証履歴](../../archive/HANDOFF-2026-10-22-path-verification.md)を参照してください。
