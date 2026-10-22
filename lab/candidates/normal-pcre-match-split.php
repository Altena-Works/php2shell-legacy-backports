<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $matches = [];
    $single = preg_match('/(?<letter>b)/', 'abc', $matches, PREG_OFFSET_CAPTURE)
        === 1 && $matches['letter'] === ['b', 1];
    $global = preg_match_all('/(a)/', 'aba', $matches, PREG_PATTERN_ORDER)
        === 2 && $matches[1] === ['a', 'a'];
    $split = preg_split('/,/', 'a,b,c') === ['a', 'b', 'c'];
    echo $single && $global && $split ? "PCRE_MATCH_SPLIT_OK\n" : "PCRE_MATCH_SPLIT_FAIL\n";
    return;
}

ini_set('memory_limit', '16M');
$subject = str_repeat('a', 1024 * 1024);
ini_set('memory_limit', '8M');
echo "READY\n";
$matches = [];
preg_match_all('/(a)/', $subject, $matches, PREG_PATTERN_ORDER);
echo "RETURNED\n";
