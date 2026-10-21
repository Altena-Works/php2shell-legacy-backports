# PHP 旧版向け緊急バックポート

[PHP 公式の CVE-2026-109618](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) と [CVE-2026-109619](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) の修正を、公式バックポートが提供されない **PHP 5〜7 の旧版**へ移植するためのリポジトリです。PHP 公式が公開した [7.4](https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2)・[8.0](https://github.com/php/php-src/commit/82f8f31b16a035c1b67cc253e79f7cc288f4cc20)・[8.1](https://github.com/php/php-src/commit/1d7dec178a094e6e75b229ce22754045f8c6070a) 向け最小バックポートは同梱しません。該当版は公式配布元を参照してください。**現在の独自移植は検証候補であり、両件の完全遮断を確認できた版はありません。**

## パッチと制限

| PHP | パッチの状態 |
| --- | --- |
| 5.6.40 | 独自の緊急候補。通常のセッション・multipart は確認済み。CVE-2026-109619 の別経路は未検証 |
| 7.3.29 / 7.3.33 | 7.4 向け公式修正を版別に移植した候補。通常動作は確認済み。完全遮断は未検証 |
| 5.4.45 / 5.5.38 / 7.0.33 / 7.1.33 / 7.2.34 | パッチ未完成。導入対象外 |

独自移植の候補は `patches/php-<版>.patch` にあります。**適用すると `session.upload_progress` が停止します。** 進捗表示を使うアプリでは影響を確認してください。5.6.40 の停止は緊急対応として許可された範囲です。版別の根拠は [設計書](BACKPORT-DESIGN.md)、暫定緩和と監視は [防御手順](DEFENSE-GUIDE.md)にあります。

**可用性上の制限：** 現行パッチは通常の `memory_limit` 超過でも PHP ワーカーを終了させます。上限到達が繰り返される環境では、隔離環境でワーカーの再起動と負荷時の挙動を確認してから導入してください。機能を維持する遅延 OOM 処理は未実装です。

## 候補パッチの検証手順

1. 稼働中の PHP の正確な版、配布元、SAPI、ビルド設定を確認し、現行のパッケージまたは Apache モジュールを退避します。対象版と一致する元ソースだけを使います。
2. リポジトリのルートで、対象版を指定して実行します。スクリプトは [PHP 旧版アーカイブ](https://museum.php.net/)から元ソースを取得し、保存済み SHA-256 との照合、fuzz なしのパッチ適用を行います。

   ```bash
   ./apply-patch.sh 7.3.29
   ```

   修正済みソースは `$HOME/php-backport-apply/<版>/php-<版>` にできます。既存の出力先は上書きしません。手元のアーカイブは `--archive /path/to/php-<版>.tar.gz`、別の保存先は `--output /path/to/work` で指定できます。SHA-256 照合は署名検証の代わりにはなりません。
3. 修正済みソースを、配布元の既存ビルド手順と同じ設定・拡張で再ビルドし、隔離した環境で PHP 版、Apache が読み込むモジュール、セッション、通常の multipart を確認します。Linux x86_64・Apache/mod_php の並列検証手順は [lab/README.md](lab/README.md)にあります。
4. 2件の防御条件と、使用する機能の互換性が確認できるまで本番導入済みの修正として扱わないでください。配布元独自の差分、PHP-FPM、LSAPI は別途検証が必要です。

## ライセンスと無保証

リポジトリの内容は [PHP License 3.01](LICENSE)で提供します。旧版ソースに付属する著作権表示とライセンスの原文は [5.6](licenses/PHP-5.6.40-LICENSE)・[7.3](licenses/PHP-7.3-LICENSE)についても保持しています。ライセンスの無保証・責任制限が適用されます。導入による不具合や損害を保証しません。
