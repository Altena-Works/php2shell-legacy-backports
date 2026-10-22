<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $value = array('keep' => 1);
    $packed = array_pad(array(1, 2), 4, $value);
    $mixed = array_pad(array('x' => 1), -3, $value);
    echo $packed === array(1, 2, $value, $value)
        && $mixed === array(0 => $value, 1 => $value, 'x' => 1)
        && $value === array('keep' => 1)
        ? "ARRAY_PAD_ARRAY_OK\n" : "ARRAY_PAD_ARRAY_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$input = isset($_GET['mixed']) ? array('x' => 1) : array(1, 2);
$pad = array('keep' => 1);
echo "READY\n";
array_pad($input, isset($_GET['negative']) ? -300000 : 300000, $pad);
echo "RETURNED\n";
