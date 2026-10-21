#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?source tree required}
version=${2:?version required}
[[ $version == 5.6.40 ]] || { echo "unexpected version: $version" >&2; exit 2; }

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        shasum -a 256 "$1" | awk '{ print $1 }'
    fi
}

# Exact outputs of this emergency patch on the recorded PHP 5.6.40 tarball.
# These hashes establish source identity, not complete CVE remediation.
while read -r expected file_path; do
    actual=$(sha256_file "$source_tree/$file_path")
    [[ $actual == "$expected" ]] || {
        echo "PHP 5.6.40 patched source mismatch: $file_path" >&2
        exit 1
    }
done <<'HASHES'
bf47f771c0b1e96482e2d67c596061d0d303c1226593ad4b4bc68a0ffde07373 Zend/zend_alloc.c
c4886c4180837efe408b8baf562cedd44f20e36ae7259e625f8918b474931604 Zend/zend_alloc.h
46939bf170b0120feeeff13ae8c773c35b5c8b512d9f4d254a22c6f638f20660 Zend/zend_execute_API.c
67cf5057ef9fe677a639fe8fd8205e8ef45bdd05c4f88104763df35f9e7715c2 Zend/zend_strtod.c
d8754daaf77ce241422b3a06fe9e01c0c377773e9922bd4f2368f17ddc420ab6 ext/session/session.c
d7339b04f9d3718b62947db250b7ce51e2008d8843e16edd64f4952ba2e9c2f7 main/SAPI.c
75200e1393fa951b1b99d6b0a0ddbcf7d94047ad95269aa3586522368dc4e261 main/main.c
HASHES
echo 'PHP 5.6.40 patched source identity verified'

python3 - "$source_tree/Zend" <<'PY'
from pathlib import Path
import sys

zend_dir = Path(sys.argv[1])
source = (zend_dir / 'zend_alloc.c').read_text()
alloc_header = (zend_dir / 'zend_alloc.h').read_text()
strtod = (zend_dir / 'zend_strtod.c').read_text()
safe_error = source.split('ZEND_API void zend_mm_safe_error_ex(', 1)[1].split('static zend_mm_free_block *zend_mm_search_large_block', 1)[0]
address = source.split('static inline size_t safe_address(', 1)[1].split('ZEND_API void *_safe_emalloc_string', 1)[0]
string_alloc = source.split('ZEND_API void *_safe_emalloc_string(', 1)[1].split('ZEND_API void *_safe_emalloc(', 1)[0]
assert 'zend_mm_safe_error_ex(format, limit,' in safe_error
assert '_exit(1);' in safe_error
assert 'zend_bailout();' not in safe_error
assert 'zend_error_noreturn(E_ERROR, "Possible integer overflow in memory allocation' not in address
assert address.count('zend_mm_safe_error_ex("Possible integer overflow in memory allocation') == 6
assert 'zend_mm_safe_error_ex("String allocation overflow, max size is %d", INT_MAX);' in string_alloc
assert 'zend_error_noreturn(E_ERROR, "String allocation overflow' not in string_alloc
assert 'ZEND_API void zend_mm_safe_error_ex(const char *format, ...);' in alloc_header
assert 'zend_error(E_ERROR, "Balloc()' not in strtod
assert strtod.count('zend_mm_safe_error_ex("Balloc()') == 2
print('CVE-2026-109618: checked allocator OOM/overflow paths terminate the worker (source check)')
PY

python3 - "$source_tree" <<'PY'
from pathlib import Path
import sys

source_tree = Path(sys.argv[1])
session = (source_tree / 'ext/session/session.c').read_text()
executor = (source_tree / 'Zend/zend_execute_API.c').read_text()
main = (source_tree / 'main/main.c').read_text()
sapi = (source_tree / 'main/SAPI.c').read_text()
assert 'if (!PS(rfc1867_enabled) || 1)' in session
shutdown = executor.split('void shutdown_executor(TSRMLS_D)', 1)[1].split('ZEND_API const char *get_active_class_name', 1)[0]
assert 'EG(error_handling) = EH_NORMAL;' in shutdown
assert 'EG(exception) = NULL;' in shutdown
assert main.count('PG(http_globals)[i] = NULL;') >= 2
assert 'SG(request_info).content_type_dup = NULL;' in sapi
print('CVE-2026-109619: upload progress disabled and selected request-boundary resets present; full closure remains unverified')
PY

echo 'CVE-2026-109619: PHP 5.6.40-specific alternate state paths are not fully verified; combined remediation is incomplete' >&2
exit 3
