<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $matches = [];
    $single = preg_match('/(?<letter>b)/', 'abc', $matches, PREG_OFFSET_CAPTURE)
        === 1 && $matches['letter'] === ['b', 1];
    $global = preg_match_all('/(a)/', 'aba', $matches, PREG_PATTERN_ORDER)
        === 2 && $matches[1] === ['a', 'a'];
    $split = preg_split('/,/', 'a,b,c') === ['a', 'b', 'c'];
    $named = preg_match_all('/(?<letter>a)/', 'aba', $matches,
        PREG_SET_ORDER | PREG_OFFSET_CAPTURE) === 2
        && $matches[0]['letter'] === ['a', 0] && $matches[1]['letter'] === ['a', 2];
    $splitOffset = preg_split('/(,)/', 'a,b', -1,
        PREG_SPLIT_DELIM_CAPTURE | PREG_SPLIT_OFFSET_CAPTURE)
        === [["a", 0], [",", 1], ["b", 2]];
    echo $single && $global && $split && $named && $splitOffset
        ? "PCRE_MATCH_SPLIT_OK\n" : "PCRE_MATCH_SPLIT_FAIL\n";
    return;
}

ini_set('memory_limit', '16M');
$mode = $_GET['limit'];
$subject = $mode === 'split'
    ? str_repeat('a,', 512 * 1024)
    : str_repeat('a', 1024 * 1024);
ini_set('memory_limit', '8M');
echo "READY\n";
$matches = [];
if ($mode === 'offset') {
    preg_match_all('/(?<letter>a)/', $subject, $matches,
        PREG_PATTERN_ORDER | PREG_OFFSET_CAPTURE);
} elseif ($mode === 'set') {
    preg_match_all('/(?<letter>a)/', $subject, $matches,
        PREG_SET_ORDER | PREG_OFFSET_CAPTURE);
} elseif ($mode === 'split') {
    preg_split('/(,)/', $subject, -1,
        PREG_SPLIT_DELIM_CAPTURE | PREG_SPLIT_OFFSET_CAPTURE);
} else {
    preg_match_all('/(a)/', $subject, $matches, PREG_PATTERN_ORDER);
}
echo "RETURNED\n";
