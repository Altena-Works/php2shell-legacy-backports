<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $packed = array_fill(0, 3, 'x');
    $mixed = array_fill(-2, 3, 'y');
    echo $packed === array('x', 'x', 'x')
        && $mixed === array(-2 => 'y', 0 => 'y', 1 => 'y')
        ? "ARRAY_FILL_OK\n" : "ARRAY_FILL_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$retained = str_repeat('x', 4 * 1024 * 1024);
echo "READY\n";
array_fill(isset($_GET['mixed']) ? -1 : 0, 200000, 'x');
echo "RETURNED\n";
