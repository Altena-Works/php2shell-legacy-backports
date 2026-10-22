<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    echo preg_replace('/(b)/', '[$1]', 'abc') === 'a[b]c'
        && preg_replace_callback('/(b)/', function ($matches) {
            return '[' . $matches[1] . ']';
        }, 'abc') === 'a[b]c'
        ? "PCRE_REPLACE_OK\n" : "PCRE_REPLACE_FAIL\n";
    return;
}

ini_set('memory_limit', '16M');
$subject = str_repeat('a', 3 * 1024 * 1024);
ini_set('memory_limit', '8M');
echo "READY\n";
preg_replace('/a/', 'bbbb', $subject);
echo "RETURNED\n";
