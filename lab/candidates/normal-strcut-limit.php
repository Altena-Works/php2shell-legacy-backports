<?php
if (!isset($_GET['limit'])) {
    $encoded = mb_convert_encoding('日本語', 'ISO-2022-JP', 'UTF-8');
    $cut = mb_strcut($encoded, 0, strlen($encoded), 'ISO-2022-JP');
    echo mb_strcut('abcdef', 0, 3, 'ISO-2022-JP') === 'abc'
        && mb_convert_encoding($cut, 'UTF-8', 'ISO-2022-JP') === '日本語'
        ? "STRCUT_OK\n" : "STRCUT_BAD\n";
    return;
}

$input = str_repeat('A', 3 * 1024 * 1024);
ini_set('memory_limit', '8M');
echo "READY\n";
flush();
mb_strcut($input, 0, strlen($input), 'ISO-2022-JP');
echo "RETURNED\n";
