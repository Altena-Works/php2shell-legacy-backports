<?php
header('Content-Type: text/plain');

$ordinary = levenshtein('kitten', 'sitting') === 3;
$weighted = levenshtein('cat', 'cut', 1, 2, 1) === 2;
$overlong = @levenshtein(str_repeat('a', 256), 'b') === -1;
echo $ordinary && $weighted && $overlong ? "LEVENSHTEIN_OK\n" : "LEVENSHTEIN_FAIL\n";
