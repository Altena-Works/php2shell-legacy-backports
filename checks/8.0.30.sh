#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?source tree required}
version=${2:?version required}
[[ $version == 8.0.30 ]] || { echo "expected PHP 8.0.30" >&2; exit 2; }

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{ print $1 }'
    else
        sha256sum "$1" | awk '{ print $1 }'
    fi
}

# Exact outputs after applying signed php/php-src commit 82f8f31b16a035c1b67cc253e79f7cc288f4cc20
# to the PHP 8.0.30 release tarball. This verifies source identity only.
while read -r expected file_path; do
    actual=$(sha256_file "$source_tree/$file_path")
    [[ $actual == "$expected" ]] || {
        echo "official backport source mismatch: $file_path" >&2
        exit 1
    }
done <<'HASHES'
856dcfdb6aef1181e7419abb8703a49b2b53110a2c979149e8ec8e09a88c8d56 Zend/zend_API.h
0267c7a07e53fa4debd32251a2d91917757667027f2fa52a9c61673296545c3d Zend/zend_alloc.c
7150919f1e839dbe9f194bcd51b9f205029de0a81060b2d537dee12c7ce790fa Zend/zend_alloc.h
bf6f04fcb331ff50cdaffbd0684254538502918e4eaecf76a49a788c55c01e7d Zend/zend_execute_API.c
4ccfebce32797c9f2ed046117eb79264464f9415a1d6fb202e7efe37e87ebdd6 Zend/zend_hash.c
13cf3f7e01869931221243a5ba96cdf75f984bc2b203e9f57c2d46047a5497f5 Zend/zend_hash.h
68d6df8452487bb8f5b935bed0b1bf05c683d3c422b9ea7309c3d3947995251f Zend/zend_llist.c
ac35d16f8592da119fd2444977c6307e6ee219321da47be7994d9d38c5878ea2 Zend/zend_multiply.h
d5b64fe5662ca74172c75142868b2c32a31f8bd455b2d94ec21654af59c9ef6e Zend/zend_strtod.c
762abe44340681eb0adf81139fbcba772d0bd9186d6201c12b793d78c90edc1d Zend/zend_types.h
b2c07ce5661695edaa3dc85c6797aa1f9dd65c11d7eb4d2103b0809feec252f4 Zend/zend_vm_def.h
fbcd1af2ee7abe559f20f3eaa67fc4fbdc177d40f506c3cc5bd03377f4f402d5 Zend/zend_vm_execute.h
954c29ed9b36552973799c7f9fb0cae2702bb370efb1787c5f559c8c91b05870 ext/session/session.c
ef0a40a0a5f2a2dd7f7e981e46db68f7043ca25cc980c87542cb023753e62cfd main/SAPI.c
1b12dcfa3b9d8e548cf4a5c18c3cdfe571f5353827da597e32cdc2c7eed20417 main/main.c
15d2a581fe531ac86784f15cc21c62d62c5e1b3c695ca1cbfb450254db3b5aa7 main/php_variables.c
7d68fdde6dbb210b7a11b8f2e35e74e172b824837bd63c66efdc399af52772b9 main/rfc1867.c
HASHES

echo "PHP 8.0.30 official EOL backport source identity verified"
echo "Compatibility limit: session.upload_progress is forced off by the official patch"
