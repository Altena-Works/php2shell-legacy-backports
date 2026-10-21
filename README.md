# PHP 旧版向け緊急バックポート

[PHP 公式の CVE-2026-109618](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) と [CVE-2026-109619](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) の修正を、公式の修正版リリースがない旧版へ移すためのパッチです。公式の最小バックポートを使える版ではその差分を採用し、それ以外は版ごとに移植しています。**このリポジトリは PHP 公式の配布物ではありません。どの版も両件の完全な遮断は実証していません。**

## パッチと制限

| PHP | パッチの状態 |
| --- | --- |
| 5.6.40 | 緊急候補。Apache/mod_php で通常のセッション・multipart を確認。CVE-2026-109619 の別経路は未検証 |
| 7.3.29 / 7.3.33 | 7.4 向け公式最小バックポートを移植。Apache/mod_php の通常動作を確認。完全遮断は未検証 |
| 7.4.33 | 公式最小バックポートと差分一致。Apache/mod_php の通常動作を確認 |
| 8.0.30 | 公式最小バックポートを適用。Apache/mod_php の通常セッション・multipart を確認 |
| 8.1.34 | 公式最小バックポートを適用。Apache/mod_php の通常セッション・multipart を確認 |
| 5.4.45 / 5.5.38 / 7.0.33 / 7.1.33 / 7.2.34 | パッチ未完成。導入対象外 |

パッチは `patches/php-<版>.patch` にあります。**適用すると `session.upload_progress` が停止します。** 進捗表示を使うアプリでは影響を確認してください。5.6.40 の停止は緊急対応として許可された範囲です。版別の根拠は [設計書](BACKPORT-DESIGN.md)、暫定緩和と監視は [防御手順](DEFENSE-GUIDE.md)にあります。

**可用性上の制限：** 現行パッチは通常の `memory_limit` 超過でも PHP ワーカーを終了させます。上限到達が繰り返される環境では、隔離環境でワーカーの再起動と負荷時の挙動を確認してから導入してください。機能を維持する遅延 OOM 処理は未実装です。

## 導入手順

1. 稼働中の PHP の正確な版、配布元、SAPI、ビルド設定を確認し、現行のパッケージまたは Apache モジュールを退避します。対象版と一致する元ソースだけを使います。
2. このリポジトリのルートで Bash を使い、次の例の `version` を上表のパッチがある版に変更して実行します。元ソースは [PHP 旧版アーカイブ](https://museum.php.net/)から取得し、保存済みの SHA-256 と照合します。

```bash
( set -e
repo_root="$PWD"
version=7.3.29
major="${version%%.*}"
archive="php-$version.tar.gz"
work_dir="$HOME/php-backport-apply/$version"
mkdir -p "$work_dir"
cd "$work_dir"

curl -fL --retry 3 "https://museum.php.net/php$major/$archive" -o "$archive"
expected="$(awk -F '\t' -v v="$version" '$1 == v { print $2 }' "$repo_root/lab/source-hashes.tsv")"
actual="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
[[ -n "$expected" && "$actual" == "$expected" ]] || { echo 'source hash mismatch' >&2; exit 1; }

tar -xzf "$archive"
cd "php-$version"
patch --dry-run --fuzz=0 --batch -p1 < "$repo_root/patches/php-$version.patch"
patch --fuzz=0 --batch -p1 < "$repo_root/patches/php-$version.patch"
)
```

3. `$HOME/php-backport-apply/<版>/php-<版>` の修正済みソースを、配布元の既存ビルド手順と同じ設定・拡張で再ビルドし、隔離した環境で PHP 版、Apache が読み込むモジュール、セッション、通常の multipart を確認します。Linux x86_64・Apache/mod_php の並列検証手順は [lab/README.md](lab/README.md)にあります。元ソースのハッシュ照合は独立した署名検証の代わりにはなりません。
4. 検証した成果物を本番の配布手順で導入し、全ワーカーを再起動します。実際の HTTP 応答から版と SAPI を確認し、問題があれば退避した成果物へ戻します。配布元独自の差分、PHP-FPM、LSAPI は別途検証が必要です。

## ライセンスと無保証

リポジトリの内容は [PHP License 3.01](LICENSE)で提供します。旧版ソースに付属する著作権表示とライセンスの原文は [5.6](licenses/PHP-5.6.40-LICENSE)・[7.3](licenses/PHP-7.3-LICENSE)についても保持しています。ライセンスの無保証・責任制限が適用されます。導入による不具合や損害を保証しません。
