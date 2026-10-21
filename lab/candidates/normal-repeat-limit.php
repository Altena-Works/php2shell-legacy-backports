<?php
if (!isset($_GET['limit'])) {
    echo str_repeat('ab', 3) === 'ababab' ? "REPEAT_OK\n" : "REPEAT_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
if (isset($_GET['aggregate'])) {
    $retained = str_repeat('a', 3 * 1024 * 1024);
    echo "RETAINED\n";
    str_repeat('b', 3 * 1024 * 1024);
    echo "RETURNED\n";
    return;
}
str_repeat('a', 32 * 1024 * 1024);
echo "RETURNED\n";
