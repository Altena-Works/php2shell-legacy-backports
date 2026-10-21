<?php
if (!isset($_GET['limit'])) {
    echo str_repeat('ab', 3) === 'ababab' ? "REPEAT_OK\n" : "REPEAT_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
str_repeat('a', 32 * 1024 * 1024);
echo "RETURNED\n";
