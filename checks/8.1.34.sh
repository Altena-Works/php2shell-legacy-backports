#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?source tree required}
version=${2:?version required}
[[ $version == 8.1.34 ]] || { echo "expected PHP 8.1.34" >&2; exit 2; }

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{ print $1 }'
    else
        sha256sum "$1" | awk '{ print $1 }'
    fi
}

# Exact outputs after applying signed php/php-src commit 1d7dec178a094e6e75b229ce22754045f8c6070a
# to the PHP 8.1.34 release tarball. This verifies source identity only.
while read -r expected file_path; do
    actual=$(sha256_file "$source_tree/$file_path")
    [[ $actual == "$expected" ]] || {
        echo "official backport source mismatch: $file_path" >&2
        exit 1
    }
done <<'HASHES'
1dcf0476c0268128e041f24d168c4c2f8c9179901ea259d24297a00b25d0fe0e Zend/zend_API.h
e74ebf2a525b7581c82b81484493adde13bdc82858549969c25238d150e827d7 Zend/zend_alloc.c
4ed591c0f6d56676bd24ca31635eda2eab98baa7d91e2482811d97e1b49e2e9b Zend/zend_alloc.h
ef32162ed27f406a1f2255670cc31a4e78f8633601c0bc98c2befcc150750a0a Zend/zend_execute_API.c
d57ffc4df504c727ad01d9404d12260d4dfe8b073f862a6262f3270b7321fadc Zend/zend_hash.c
28cee98b653922e07537a55bbc727361ad03edd62eb60ef27dbbda6054bce4ca Zend/zend_hash.h
ac35d16f8592da119fd2444977c6307e6ee219321da47be7994d9d38c5878ea2 Zend/zend_multiply.h
c7361d36f7d8fe0e27112b9f6a084cfea534aabbec16d73d6e56f3c22d16795c Zend/zend_strtod.c
13a25256efeb2799acaa4a5f58cdbfc4c688054b657a4298d9bdf880d9327aa1 Zend/zend_types.h
ccc51a8f1830ef3b108146d6ff38edd0583723be484a38ed5d993aefb353a338 Zend/zend_vm_def.h
bf1ba96b8f8ab7f0cab10409fecadaa74cc127c6077759af118a1e567ba24c45 Zend/zend_vm_execute.h
df9ea0d106b378b5da01c3bf34d8da850de9b1f25298448443a9101fc5eaceee ext/opcache/ZendAccelerator.c
75cd5120585b96be95e200ec72167812758b2a9065031ed4adad312e7dc4623d ext/opcache/ZendAccelerator.h
f4f39ba24c28f01f8454bfa911ae4d3b74cc881d723dbe287215b69be5c59397 ext/opcache/zend_file_cache.c
8189139542290e37799a18889a3f4e0c7baf5c7853f6ff5c98509c6e38fd62f7 ext/opcache/zend_persist.c
80233ee61c86faa1f4364fdc3f74701cb16bf0b0137ff7e43a83b750c36d49e9 ext/session/session.c
74b1da9ed4eae5a1a8a0c810bb04c958b928f33754dfafa35e424fd737341778 ext/zend_test/tests/observer_bug81430_2.phpt
d3296345ada2d08f398fd7be2fa08f2dadc9468cb244fa3f63f98e26d2f8c910 ext/zend_test/tests/observer_bug81435.phpt
11c9b8ff8c1326719f6c8d24eb362891dfa4e258e7e2b1562ac78a3ed0faef50 ext/zend_test/tests/observer_error_01.phpt
66149a4ba3d4e07c7d78761bb79241a1aa920fa7b904066025b41caf7ff2f29a main/SAPI.c
e60763cf374070f6268f1be01c8244217679fa8ac712a5e66252fa6f8774547e main/main.c
4d0c7e6395317714fc8e0dd07edeef51a12bd43cbdf9a011048086a204d84740 main/php_variables.c
2a2fba1c5b105d70fe8566a03e6326c0b3e1039452ce3ada81395afe32843844 main/rfc1867.c
HASHES

echo "PHP 8.1.34 official EOL backport source identity verified"
echo "Compatibility limit: session.upload_progress is forced off by the official patch"
