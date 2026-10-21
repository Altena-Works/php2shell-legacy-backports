# Linux x86_64・Apache/mod_php 検証ラボ

このラボは各版のソースを別の作業木で修正し、`linux/amd64` コンテナ内で Apache モジュールをビルドします。Web ポートは公開せず、コンテナ内の loopback から通常の HTTP とセッションを確認します。macOS では Podman VM を起動してください。ARM ホスト上の amd64 変換実行はネイティブ x86_64 と同じヒープ配置や競合タイミングを保証しません。

標準のパッチ検証対象は、このリポジトリで独自移植した 5.6.40・7.3.33 です。各 `x.y` 系列の最終 `z` のみを対象にし、7.4.33 は公式バックポートを参照する比較用です。PHP 公式が配布する 7.4・8.0・8.1 の最小バックポートはここに含めません。`pass` も脆弱性の完全遮断を意味しません。

## 準備

リポジトリのルートで、使う版に応じたビルダーを作ります。PHP 5.x 用は古い Debian のパッケージを使うため、このラボだけに使ってください。

```bash
podman build --platform linux/amd64 -t localhost/php-backport-build:5.6 -f lab/Containerfile.php56 .
podman build --platform linux/amd64 -t localhost/php-backport-build:7.4 -f lab/Containerfile.php74 .
```

ソースは [PHP 旧版アーカイブ](https://museum.php.net/)から `php-<版>.tar.gz` を取得します。例えば 7.3.33 は `https://museum.php.net/php7/php-7.3.33.tar.gz` です。`lab/source-hashes.tsv` は各系列の最終版アーカイブの SHA-256 を固定しており、スクリプトは一致しない入力を拒否します。この照合は独立した署名検証ではありません。

全12系列（PHP 5.0〜5.6、7.0〜7.4）のアーカイブと session ソースの有無は `python3 lab/check-series-sources.py "$source_dir"` で照合できます。これはソース棚卸しであり、脆弱性の非該当判定や実行テストではありません。

## 版ごとの適用と起動

必要なパッチと `checks/<版>.sh` がある版を指定します。以下の `source_dir` にアーカイブを置きます。4 CPU・4 GiB の VM では同時数 `--jobs 2` を使います。

```bash
source_dir="$HOME/php-backport-lab/sources"
results_dir="$HOME/php-backport-lab/results"
mkdir -p "$source_dir" "$results_dir"

lab/run-matrix.sh --mode patch \
  --versions 5.6.40,7.3.33 --jobs 2 \
  --source-dir "$source_dir" --results-dir "$results_dir" \
  --patch-dir "$PWD/patches" --check-dir "$PWD/checks"
```

単一版だけ試す場合は、例えば `--versions 7.3.33 --jobs 1` に変更します。無修正の比較は `--mode baseline` とし、パッチモードとは異なる `--results-dir` を指定します。版を省略した baseline モードは12系列の最終版を選びます。結果は `$results_dir/<mode>/<版>/` の `status`、`runtime.txt`、`defense-check.log`、各ビルドログに残ります。作業木は `$results_dir/work/<版>/` です。パッチ変更後も新しい `--results-dir` を使い、以前の差分に重ねて適用しません。

`pass` は厳密なパッチ適用、ビルド、Apache のロードモジュール一致、通常 HTTP・セッション、版別のソース検査が通った意味です。悪用不能性の証明ではありません。5.6.40 と 7.3.33 の `fail (3)` は、限定的な防御条件を確認しても、公式と同等の修正が未完成であることを示す意図的な判定です。詳細は `runtime.txt` と `defense-check.log` を確認してください。

upload progress の機能制限は、通常の小さな multipart 投稿で別途確認できます。この検査は管理設定で progress を有効、cleanup を無効にした上で、修正済み版では `PROGRESS_ABSENT` を期待します。

```bash
version=7.3.33
lab/check-multipart-progress.sh "$results_dir/work/$version/php-$version" "$version" PROGRESS_ABSENT
```
