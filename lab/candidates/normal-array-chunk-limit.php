<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $input = array('a' => 1, 'b' => 2, 'c' => 3);
    echo array_chunk($input, 2) === array(array(1, 2), array(3))
        && array_chunk($input, 2, true) === array(
            array('a' => 1, 'b' => 2), array('c' => 3))
        ? "ARRAY_CHUNK_OK\n" : "ARRAY_CHUNK_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$input = array_fill(0, 100000, 0);
echo "READY\n";
array_chunk($input, isset($_GET['inner']) ? 100 : 1);
echo "RETURNED\n";
