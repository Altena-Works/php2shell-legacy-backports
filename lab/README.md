# 旧版 PHP の並列検証環境

`run-matrix.sh` は候補版をまとめて処理する。初期値は 5.4.45、5.5.38、5.6.40、7.0.33、7.1.33、7.2.34、7.3.29、7.3.33、7.4.33、8.0.30、8.1.34。`--jobs` が同時実行数で、十分な資源があれば `--jobs 11` で全版を同時に処理できる。4 CPU・4 GiB の検証 VM では初期値の 2 を使う。各版を独立したコンテナで処理し、外部ポートを公開しない。`--network none` で起動し、同じコンテナのループバックへ通常の HTTP リクエストを送る。

```bash
lab/run-matrix.sh --mode baseline --versions 5.6.40,7.3.29,7.4.33 --jobs 2
lab/run-matrix.sh --mode patch --patch-dir /absolute/path/to/patches \
  --check-dir /absolute/path/to/checks --jobs 2
```

元ソースは既定で `/private/tmp/php-backport-sources/php-<version>.tar.gz` を使う。`--source-dir` で変更できる。アーカイブの SHA-256 が `source-hashes.tsv` と一致しない場合は中止する。この一覧は作業中に取得した配布物を固定するための値であり、独立した署名検証の代わりではない。必要なビルダーイメージは `Containerfile.php56`、`Containerfile.php74`、`Containerfile.php81` から事前に構築する。

修正後の実行には、各版の統合差分 `patches/php-<version>.patch` と、公式修正が守る条件を安全な手段で検査する実行可能な `checks/<version>.sh` を用意する。検査スクリプトには第 1 引数で展開済みソースのパス、第 2 引数で版番号を渡す。**公式修正の公開前に防御条件を推測して検査を埋めない。** 必要なパッチや検査が欠けた版は失敗とする。

作業木は `<results-dir>/work/<version>/` に残す。再実行時は元アーカイブのハッシュを照合してから中間成果物を再利用する。パッチを適用した作業木へ同じパッチを重ねず、別のパッチや無修正ベースラインを混ぜようとした場合は失敗する。各版はパッチの厳密な dry-run と適用後、Apache/mod_php をソースからビルドする。ビルド結果と Apache に導入されたモジュールのファイル一致を確認し、`health.php` で版番号、`apache2handler`、通常のセッション読み書きを確認する。パッチモードでは続いて版別の防御条件検査を通す。結果は既定で `/private/tmp/php-backport-results/<mode>/<version>/` に保存する。`--results-dir` で変更できる。

PHP 5.6 用の Debian Stretch 開発パッケージは 2026 年時点で署名鍵が期限切れのため、隔離した検証イメージに限ってアーカイブから取得した。このビルダーを本番環境へ転用しない。ARM ホスト上の amd64 変換実行なので、ネイティブ x86_64 の競合タイミングやヒープ配置は再現を保証しない。ベースラインの成功は、修正の安全性を意味しない。

PHP 5.6.40 の緊急候補では、`check-php56-multipart.sh <展開済みソース> PROGRESS_ABSENT` が良性 multipart と通常セッションを確認する。比較元で進捗機能が動く場合は `PROGRESS_PRESENT` を指定する。`checks/5.6.40.sh` は CVE-2026-109619 の全経路が未検証であることを終了コード 3 で示すため、matrix の `fail (3)` はビルド失敗と区別して `runtime.txt` と `defense-check.log` を確認する。
