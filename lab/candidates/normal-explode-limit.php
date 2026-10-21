<?php
if (!isset($_GET['limit'])) {
    $positive = explode(',', 'a,b,') === array('a', 'b', '');
    $negative = explode(',', 'a,b,c', -1) === array('a', 'b');
    $legacy = explode(',', 'a,b', 1) === array('a,b');
    $many = explode(',', str_repeat('a,', 80), -1);
    echo $positive && $negative && $legacy && count($many) === 80
        ? "EXPLODE_OK\n" : "EXPLODE_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
if (isset($_GET['terminal'])) {
    $input = str_repeat('a', 4 * 1024 * 1024);
    $input[4 * 1024 * 1024 - 2] = ',';
    $input[4 * 1024 * 1024 - 1] = 'x';
    echo "READY\n";
    flush();
    explode(',', $input, 2);
    echo "RETURNED\n";
    return;
}
$input = str_repeat('ab,', 300000);
echo "READY\n";
flush();
explode(',', $input, isset($_GET['negative']) ? -1 : PHP_INT_MAX);
echo "RETURNED\n";
