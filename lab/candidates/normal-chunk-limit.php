<?php
if (!isset($_GET['limit'])) {
    echo chunk_split('ABCDE', 2, '|') === 'AB|CD|E|'
        && chunk_split('A', 4, '|') === 'A|'
        && chunk_split('', 76, '|') === '|'
        ? "CHUNK_OK\n" : "CHUNK_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
$input = str_repeat('a', 1024 * 1024);
chunk_split($input, 1, '1234567890abcdef');
echo "RETURNED\n";
