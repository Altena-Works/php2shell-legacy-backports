# PHP 旧版向け緊急バックポート検証

PHP の [CVE-2026-109618](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) と [CVE-2026-109619](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) に対する旧版の修正候補を、隔離した Linux x86_64・Apache/mod_php 環境でビルドして確認するためのリポジトリです。**このリポジトリのパッチは本番配布物ではなく、両 CVE の完全な遮断も確認できていません。** 本番環境では [PHP 公式の修正版](https://www.php.net/archive/2026.php)または配布元が両件を修正した版への更新を優先してください。

## 対象版と現在の範囲

| PHP | パッチ | ローカル検証の範囲 |
| --- | --- | --- |
| 5.6.40 | `patches/php-5.6.40.patch` | 厳密適用、クリーンビルド、Apache/mod_php、通常セッション・multipart、upload progress 停止。別の状態経路は未検証 |
| 7.3.29 / 7.3.33 | 版別の `patches/php-<版>.patch` | 厳密適用、ビルド、Apache/mod_php、通常セッション・multipart、ソース検査 |
| 7.4.33 | `patches/php-7.4.33.patch` | 公式の最小バックポートと差分一致。ビルド、Apache/mod_php、通常セッション・multipart |
| 8.0.30 / 8.1.34 | 版別の `patches/php-<版>.patch` | 公式の最小バックポートを厳密適用、ソース検査。実行確認は進行中 |
| 5.4.45 / 5.5.38 / 7.0.33 / 7.1.33 / 7.2.34 | なし | ソース取得のみ。版固有パッチと修正後の実行確認は未完了 |

5.6.40、7.3 系、7.4.33、8.0.30、8.1.34 の緊急候補は `session.upload_progress` を停止します。進捗表示に依存するアプリでは動作が変わります。5.6.40 の停止は緊急対応として許可された範囲です。版別の根拠と限界は [設計書](BACKPORT-DESIGN.md)、運用側の暫定策は [防御手順](DEFENSE-GUIDE.md)を参照してください。

## 1. 検証用 PHP を用意する

以下は **検証用コンテナ内** に各版の Apache モジュールをソースから組み込む手順です。本番ホストへのインストールやサービスの切り替えは行いません。作業場所はこのリポジトリのルート、シェルは Bash を想定します。Podman、`curl`、`shasum`、`awk` が必要です。macOS では Podman VM を先に起動します。VM がなければ、先に `podman machine init --cpus 4 --memory 4096 --disk-size 10 php-backport-lab` で作成します。Linux 上の Podman では VM 起動は不要です。

```bash
# macOS で既存の検証 VM を使う場合
podman machine start php-backport-lab

# 使う版に対応するビルダーだけ作る。5.6 用は古い Debian のパッケージを使うため検証専用。
# 5.x 用
podman build --platform linux/amd64 -t localhost/php-backport-build:5.6 -f lab/Containerfile.php56 .
# 7.x 用
podman build --platform linux/amd64 -t localhost/php-backport-build:7.4 -f lab/Containerfile.php74 .
# 8.x 用
podman build --platform linux/amd64 -t localhost/php-backport-build:8.1 -f lab/Containerfile.php81 .
```

必要な版だけを PHP の[旧版アーカイブ](https://museum.php.net/)から取得します。次の `versions` を変えるだけで、単一版にも複数版にも使えます。ハッシュが [固定一覧](lab/source-hashes.tsv)と異なれば、そのアーカイブは使わずに取得元を確認してください。

```bash
source_dir="$HOME/php-backport-lab/sources"
results_dir="$HOME/php-backport-lab/results"
mkdir -p "$source_dir" "$results_dir"
versions=(5.6.40 7.3.29 7.3.33 7.4.33 8.0.30 8.1.34)

for version in "${versions[@]}"; do
  archive="$source_dir/php-$version.tar.gz"
  if [[ ! -f "$archive" ]]; then
    major="${version%%.*}"
    curl -fL --retry 3 "https://museum.php.net/php$major/php-$version.tar.gz" -o "$archive"
  fi
  expected="$(awk -F '\t' -v v="$version" '$1 == v { print $2 }' lab/source-hashes.tsv)"
  actual="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
  [[ -n "$expected" && "$actual" == "$expected" ]] || {
    printf 'SHA-256 mismatch: %s\n' "$archive" >&2
    exit 1
  }
done
```

この照合は、この作業で固定した配布アーカイブとの一致確認です。独立した署名検証の代わりにはなりません。

## 2. 指定版へパッチを適用して起動確認する

`--versions` にカンマ区切りで版を指定します。4 CPU・4 GiB の検証 VM では `--jobs 2` を使います。各版は別の作業木を使い、パッチを fuzz なしで適用してからビルドします。Apache は外部ポートを開かず、コンテナ内の loopback から通常の HTTP 応答とセッション読み書きを確認します。

```bash
# 例: PHP 7.3.29 だけ
lab/run-matrix.sh --mode patch --versions 7.3.29 --jobs 1 \
  --source-dir "$source_dir" --results-dir "$results_dir" \
  --patch-dir "$PWD/patches" --check-dir "$PWD/checks"

# 例: パッチがある版を並列確認
lab/run-matrix.sh --mode patch \
  --versions 5.6.40,7.3.29,7.3.33,7.4.33,8.0.30,8.1.34 --jobs 2 \
  --source-dir "$source_dir" --results-dir "$results_dir" \
  --patch-dir "$PWD/patches" --check-dir "$PWD/checks"
```

結果は `$results_dir/patch/<版>/` の `status`、`runtime.txt`、`defense-check.log`、ビルドログに残ります。`pass` はパッチ適用、ビルド、通常 HTTP、版別のソース検査を通った意味であり、悪用不能性の証明ではありません。**5.6.40 の `fail (3)` は意図的な未完了判定**です。`runtime.txt` の正常応答と `defense-check.log` の未検証経路を別々に確認してください。検証環境と判定の詳細は [lab/README.md](lab/README.md)に記録しています。

パッチを変更したときは、同じ作業木に重ねず、新しい `--results-dir` を指定してください。パッチのない版を `--mode patch` に含めると、その版は失敗します。修正前の動作だけを確認する場合は `--mode baseline` を指定します。

## 本番環境への反映前に

アプリが使う拡張、SAPI、セッション設定、upload progress、multipart の入力制限を確認し、対象 OS と実際の PHP ビルドで別途検証してください。この検証環境は arm64 ホスト上で amd64 を変換実行しており、ネイティブ x86_64 の競合タイミングやヒープ配置を再現する保証はありません。PHP-FPM、LSAPI、独自の配布元パッチについても、この結果は適用できません。暫定隔離、ログ監視、更新後のワーカー入れ替えは [防御手順](DEFENSE-GUIDE.md)に従ってください。
