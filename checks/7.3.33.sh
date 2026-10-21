#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?source tree required}
version=${2:?version required}
[[ $version == 7.3.33 ]] || exit 2
[[ -d $source_tree ]] || exit 2

rg -Fq 'if (!PS(rfc1867_enabled) || true)' "$source_tree/ext/session/session.c"
rg -Fq 'zend_mm_safe_error_ex(format, limit,' "$source_tree/Zend/zend_alloc.c"
rg -Fq '_exit(1);' "$source_tree/Zend/zend_alloc.c"
rg -Fq '#define ZSTR_MAX_LEN (SIZE_MAX - ZSTR_MAX_OVERHEAD)' "$source_tree/Zend/zend_string.h"
rg -Fq 'ZVAL_UNDEF(&PG(http_globals)[i]);' "$source_tree/main/main.c"
rg -Fq 'Multipart body parts limit exceeded' "$source_tree/main/rfc1867.c"

python3 - "$source_tree" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
for file_name, expected in [('Zend/zend_vm_def.h', (2, 0)),
                            ('Zend/zend_vm_execute.h', (17, 8))]:
    lines = (root / file_name).read_text().splitlines()
    handler = ''
    counts = [0, 0]
    for index, line in enumerate(lines):
        match = re.search(r'ZEND_((?:FAST_)?CONCAT_SPEC_[A-Z_]+)_HANDLER', line)
        if match:
            handler = match.group(1)
        extend = 'zend_string_extend(op1_str, len + ZSTR_LEN(op2_str)' in line
        alloc = ('zend_string_alloc(ZSTR_LEN(op1_str) + ZSTR_LEN(op2_str)' in line
                 and handler.startswith('CONCAT_SPEC_'))
        if file_name.endswith('zend_vm_def.h'):
            alloc = False
        if not (extend or alloc):
            continue
        if not any('ZSTR_MAX_LEN - ZSTR_LEN(op2_str)' in previous
                   for previous in lines[max(0, index - 5):index]):
            raise SystemExit(f'missing concat length guard: {file_name}:{index + 1}')
        counts[0 if extend else 1] += 1
    if tuple(counts) != expected:
        raise SystemExit(f'unexpected concat path count: {file_name}: {counts}')
PY

printf '%s\n' 'Emergency candidate source checks passed.'
printf '%s\n' 'Feature limitation: session.upload_progress is disabled by this patch.'
printf '%s\n' 'Compatibility change: multipart parts gain a default limit and only the first used header is kept.'
printf '%s\n' 'Compatibility change: an out-of-memory condition exits the worker immediately.'
printf '%s\n' 'This check plus ordinary Apache/session health does not prove complete remediation of both CVEs.'
