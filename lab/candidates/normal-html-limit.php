<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    echo htmlentities('A&B', ENT_QUOTES, 'UTF-8') === 'A&amp;B'
        ? "HTML_OK\n" : "HTML_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$input = str_repeat('&', 3 * 1024 * 1024);
echo "READY\n";
htmlentities($input, ENT_QUOTES, 'UTF-8');
echo "RETURNED\n";
