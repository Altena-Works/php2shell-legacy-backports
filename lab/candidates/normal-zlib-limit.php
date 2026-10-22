<?php
if (!isset($_GET['limit'])) {
    $plain = "alpha\nbeta\n";
    $compressed = gzencode($plain);
    $context = inflate_init(ZLIB_ENCODING_GZIP);
    $decoded = inflate_add($context, $compressed, ZLIB_FINISH);
    $file = tempnam(sys_get_temp_dir(), 'zlib-check-');
    file_put_contents($file, $compressed);
    $lines = gzfile($file);
    unlink($file);
    $stream = fopen('php://temp', 'w+');
    fwrite($stream, gzdeflate($plain));
    rewind($stream);
    stream_filter_append($stream, 'zlib.inflate', STREAM_FILTER_READ);
    $filtered = stream_get_contents($stream);
    fclose($stream);
    echo $decoded === $plain && $lines === ["alpha\n", "beta\n"] && $filtered === $plain
        ? 'ZLIB_OK' : 'ZLIB_BAD';
    return;
}

$context = deflate_init(ZLIB_ENCODING_RAW);
$block = str_repeat('x', 65536);
$compressed = '';
for ($i = 0; $i < 192; $i++) {
    $compressed .= deflate_add($context, $block, ZLIB_NO_FLUSH);
}
$compressed .= deflate_add($context, '', ZLIB_FINISH);
if ($_GET['limit'] === 'filter') {
    $stream = fopen('php://temp', 'w+');
    fwrite($stream, $compressed);
    rewind($stream);
    stream_filter_append($stream, 'zlib.inflate', STREAM_FILTER_READ);
}
ini_set('memory_limit', '8M');
echo 'READY';
if ($_GET['limit'] === 'filter') {
    stream_get_contents($stream);
} elseif ($_GET['limit'] === 'decode') {
    gzinflate($compressed);
} else {
    $inflate = inflate_init(ZLIB_ENCODING_RAW);
    inflate_add($inflate, $compressed, ZLIB_FINISH);
}
echo 'RETURNED';
