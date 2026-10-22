# SimpleXML/GC 二重解放報告の版別判定（2026-10-22）

## 確認できたこと

[PHP公式 Issue #24488](https://github.com/php/php-src/issues/24488) は、PHP 8.4.27/8.5.12でSimpleXMLのpropertiesテーブルがGCによって二重解放される回帰として `Status: Verified`。原因はGH-24050の変更で、GCが `get_gc()` の返すHashTableをgarbage bufferへ追加する一方、SimpleXMLが別の解放経路を使うこと。[修正PR #24494](https://github.com/php/php-src/pull/24494) は確認時点でopenであり、リリース済み修正としては扱わない。投稿されたSNS画像とこのIssueが同一事象かは、画像だけでは確定できない。

## このリポジトリの旧版候補

7.3.33の固定ソースと現候補では、`Zend/zend_gc.c` の `gc_collect_white()` はオブジェクト自身をgarbage bufferへ追加するが、`get_gc()` の返した `ht` に対してGH-24050由来の `gc_add_garbage((zend_refcounted *)ht)` を行わない。`ext/simplexml/simplexml.c` の `sxe_get_gc()` は `sxe->properties` を返し、解放時は `zend_hash_destroy()` と `FREE_HASHTABLE()` を使う。同じ旧版の組み合わせには、Issue #24488で特定された「GCへ追加されたテーブルをSimpleXMLが先に解放する」という条件がない。したがってPR #24494の一行修正を7.3.33へ機械的に移植しない。これは7.3.33に別の二重解放がないという証明ではない。

5.6.40の元ソースには現行の `gc_collect_white()` と同じ構造がなく、`zobj_*` 系のGC経路である。GH-24050回帰の直接移植対象にはしない。その他の旧版も各系列のGC実装と `get_gc()` の所有権を判定する。旧版固有の二重解放が見つかれば、版別に修正と通常機能・安全なGC検査を追加する。攻撃コードやPoCは取得・実行しない。

固定済み元アーカイブの全12系列最終版（5.0.5〜7.4.33）の `Zend/zend_gc.c` も読み取り照合した。5.0〜5.2には同名ファイルがなく、5.3〜7.4にはIssueの原因ハンク `gc_add_garbage((zend_refcounted *)ht)` が存在しない。これは特定のGH-24050回帰がこれらの元版に導入されていない証拠であり、別のGC欠陥の不存在証明ではない。

この判定はソース上の原因照合であり、7.3.33と5.6.40に対するASAN/Valgrindによる全GC経路の実測ではない。両CVEの遮断判定とも別に記録する。
