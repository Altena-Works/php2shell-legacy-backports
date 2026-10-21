<?php
if (!isset($_GET['limit'])) {
    $encoded = json_encode(array('name' => 'ordinary', 'items' => array(1, 2)), JSON_PARTIAL_OUTPUT_ON_ERROR);
    $partial = json_encode(array('name' => "\xff"), JSON_PARTIAL_OUTPUT_ON_ERROR);
    echo $encoded === '{"name":"ordinary","items":[1,2]}'
        && $partial === '{"name":null}' ? "JSON_OK\n" : "JSON_BAD\n";
    return;
}

ini_set('memory_limit', '16M');
$value = str_repeat('a', 3 * 1024 * 1024);
ini_set('memory_limit', '8M');
json_encode(array($value, $value, $value), JSON_PARTIAL_OUTPUT_ON_ERROR);
echo "RETURNED\n";
