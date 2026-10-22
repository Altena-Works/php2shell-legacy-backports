<?php
if (!isset($_GET['limit']) && !isset($_GET['escape']) && !isset($_GET['decode']) && !isset($_GET['string_decode'])) {
    $encoded = json_encode(array('name' => 'ordinary', 'items' => array(1, 2)), JSON_PARTIAL_OUTPUT_ON_ERROR);
    $partial = json_encode(array('name' => "\xff"), JSON_PARTIAL_OUTPUT_ON_ERROR);
    $decoded_object = json_decode('{"name":"ordinary","items":[1,2]}');
    $decoded_array = json_decode('{"name":"ordinary","items":[1,2]}', true);
    echo $encoded === '{"name":"ordinary","items":[1,2]}'
        && $partial === '{"name":null}'
        && $decoded_object->name === 'ordinary' && $decoded_object->items === [1, 2]
        && $decoded_array === ['name' => 'ordinary', 'items' => [1, 2]]
        ? "JSON_OK\n" : "JSON_BAD\n";
    return;
}

if (isset($_GET['decode'])) {
    ini_set('memory_limit', '16M');
    $value = '[' . str_repeat('0,', 1200000) . '0]';
    ini_set('memory_limit', '8M');
    echo "READY\n";
    json_decode($value);
    echo "RETURNED\n";
    return;
}

if (isset($_GET['string_decode'])) {
    ini_set('memory_limit', '16M');
    $content = str_repeat('a', 5 * 1024 * 1024);
    $value = '"' . $content . '"';
    unset($content);
    ini_set('memory_limit', '8M');
    echo "READY\n";
    json_decode($value);
    echo "RETURNED\n";
    return;
}

ini_set('memory_limit', '16M');
$value = str_repeat(isset($_GET['escape']) ? '"' : 'a', 3 * 1024 * 1024);
ini_set('memory_limit', '8M');
json_encode(isset($_GET['escape']) ? $value : array($value, $value, $value), JSON_PARTIAL_OUTPUT_ON_ERROR);
echo "RETURNED\n";
