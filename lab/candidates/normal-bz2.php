<?php
if (!extension_loaded('bz2')) {
    echo "BZ2_MISSING\n";
    exit;
}

$mode = $_GET['mode'] ?? 'normal';
if ($mode === 'normal') {
    $plain = str_repeat('ordinary data ', 4096);
    $compressed = bzcompress($plain);
    $restored = is_string($compressed) ? bzdecompress($compressed) : false;
    if ($restored !== $plain) {
        echo "BZ2_FAILED\n";
        exit;
    }
    $stream = fopen('php://temp', 'w+');
    $filter = stream_filter_append($stream, 'bzip2.compress', STREAM_FILTER_WRITE);
    if (!$filter || fwrite($stream, $plain) !== strlen($plain)) {
        echo "BZ2_FILTER_FAILED\n";
        exit;
    }
    stream_filter_remove($filter);
    rewind($stream);
    $filtered = stream_get_contents($stream);
    fclose($stream);
    if (bzdecompress($filtered) !== $plain) {
        echo "BZ2_FILTER_FAILED\n";
        exit;
    }
    echo "BZ2_OK\n";
    exit;
}

if ($mode === 'decompress-limit') {
    $plain = str_repeat('A', 6 * 1024 * 1024);
    $compressed = bzcompress($plain);
    unset($plain);
    if (!is_string($compressed) || ini_set('memory_limit', '8M') === false) {
        echo "SETUP_FAILED\n";
        exit;
    }
    echo "READY\n";
    bzdecompress($compressed);
    echo "RETURNED\n";
    exit;
}

echo "UNKNOWN_MODE\n";
