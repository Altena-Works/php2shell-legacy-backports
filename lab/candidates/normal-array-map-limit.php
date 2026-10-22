<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $left = array(1, 2);
    $right = array(3, 4);
    $mapped = array_map(function ($a, $b) { return $a + $b; }, $left, $right);
    echo array_map(null, $left, $right) === array(array(1, 3), array(2, 4))
        && $mapped === array(4, 6)
        ? "ARRAY_MAP_OK\n" : "ARRAY_MAP_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$count = isset($_GET['inner']) ? 60000 : 100000;
$input = array_fill(0, $count, 1);
echo "READY\n";
array_map(null, $input, $input);
echo "RETURNED\n";
