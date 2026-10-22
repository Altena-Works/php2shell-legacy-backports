<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    echo unpack('Cfirst/Csecond', "\x01\x02") === array('first' => 1, 'second' => 2)
        ? "UNPACK_OK\n" : "UNPACK_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$input = str_repeat('x', 1024 * 1024);
echo "READY\n";
unpack('C*', $input);
echo "RETURNED\n";
