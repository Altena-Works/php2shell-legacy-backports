<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    echo range(1, 3) === array(1, 2, 3)
        && range(1.0, 3.0, 1.0) === array(1.0, 2.0, 3.0)
        ? "RANGE_OK\n" : "RANGE_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$retained = str_repeat('x', 4 * 1024 * 1024);
echo "READY\n";
if (isset($_GET['double'])) {
    range(1.0, 200000.0, 1.0);
} else {
    range(1, 200000);
}
echo "RETURNED\n";
