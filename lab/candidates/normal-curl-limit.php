<?php
$path = tempnam(sys_get_temp_dir(), 'curl-check-');
$stream = fopen($path, 'wb');
$block = str_repeat('x', 65536);
$blocks = isset($_GET['limit']) ? 192 : 1;
for ($i = 0; $i < $blocks; $i++) {
    fwrite($stream, $block);
}
fclose($stream);

$handle = curl_init('file://' . $path);
curl_setopt($handle, CURLOPT_RETURNTRANSFER, true);
if (isset($_GET['limit'])) {
    ini_set('memory_limit', '8M');
    echo 'READY';
    curl_exec($handle);
    echo 'RETURNED';
} else {
    $result = curl_exec($handle);
    echo strlen($result) === strlen($block) && $result === $block ? 'CURL_OK' : 'CURL_BAD';
    curl_close($handle);
    unlink($path);
}
