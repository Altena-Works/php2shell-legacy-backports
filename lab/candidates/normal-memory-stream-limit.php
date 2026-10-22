<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $stream = fopen('php://memory', 'w+');
    fwrite($stream, 'abc');
    $ok = ftruncate($stream, 5) && rewind($stream) && fread($stream, 5) === "abc\0\0";
    fclose($stream);
    echo $ok ? "MEMORY_STREAM_OK\n" : "MEMORY_STREAM_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$stream = fopen('php://memory', 'w+');
echo "READY\n";
if (isset($_GET['truncate'])) {
    ftruncate($stream, 16777216);
} else {
    $block = str_repeat('a', 65536);
    for ($i = 0; $i < 256; ++$i) {
        fwrite($stream, $block);
    }
}
fclose($stream);
echo "RETURNED\n";
