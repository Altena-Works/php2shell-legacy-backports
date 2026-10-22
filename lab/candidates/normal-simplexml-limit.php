<?php
if (!isset($_GET['limit'])) {
    $xml = simplexml_load_string('<root><item code="one">alpha</item><item code="two">beta</item></root>');
    $matches = $xml->xpath('//item');
    $properties = (array) $xml->item[0];
    $iteratedKeys = [];
    foreach ($xml->item as $key => $value) {
        $iteratedKeys[] = $key;
    }
    libxml_use_internal_errors(true);
    simplexml_load_string('<root>');
    $errors = libxml_get_errors();
    libxml_clear_errors();
    echo $xml->getName() === 'root'
        && count($matches) === 2
        && (string) $xml->item[0] === 'alpha'
        && (string) $xml->item[0]['code'] === 'one'
        && isset($properties['@attributes']['code'])
        && $iteratedKeys === ['item', 'item']
        && count($errors) > 0
        ? 'SIMPLEXML_OK' : 'SIMPLEXML_BAD';
    return;
}

ini_set('memory_limit', '8M');
echo 'READY';
$xml = simplexml_load_file('/tmp/simplexml-large.xml', 'SimpleXMLElement', LIBXML_PARSEHUGE);
$text = (string) $xml->item[0];
echo 'RETURNED';
