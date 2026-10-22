<?php
if (!extension_loaded('iconv')) {
    exit('ICONV_MISSING');
}

if (!isset($_GET['limit'])) {
    if (iconv('UTF-8', 'UTF-16LE', 'Hello') !== "H\0e\0l\0l\0o\0") {
        exit('ICONV_CONVERT_FAIL');
    }
    $encoded = iconv_mime_encode('Subject', 'Hello', array('input-charset' => 'UTF-8', 'output-charset' => 'UTF-8'));
    if (!is_string($encoded) || strpos($encoded, 'Subject:') !== 0) {
        exit('ICONV_MIME_FAIL');
    }
    $stream = fopen('php://temp', 'w+');
    stream_filter_append($stream, 'convert.iconv.UTF-8.UTF-16LE', STREAM_FILTER_WRITE);
    fwrite($stream, 'OK');
    rewind($stream);
    if (stream_get_contents($stream) !== "O\0K\0") {
        exit('ICONV_FILTER_FAIL');
    }
    fclose($stream);
    exit('ICONV_OK');
}

ini_set('memory_limit', '8M');
$input = file_get_contents('/tmp/iconv-large.txt');
echo "READY\n";
$converted = iconv('UTF-8', 'UTF-16LE', $input);
echo "RETURNED\n";
