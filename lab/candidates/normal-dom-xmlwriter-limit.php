<?php
if (!extension_loaded('dom') || !extension_loaded('xmlwriter')) {
    exit('XML_EXTENSION_MISSING');
}

if (!isset($_GET['limit'])) {
    $document = new DOMDocument();
    $document->loadXML('<root><item>A</item><item>B</item></root>');
    $xpath = new DOMXPath($document);
    $nodes = $xpath->query('//item');
    if ($nodes->length !== 2 || $nodes->item(1)->textContent !== 'B') {
        exit('DOM_XPATH_FAIL');
    }
    $writer = xmlwriter_open_memory();
    xmlwriter_start_element($writer, 'root');
    xmlwriter_write_element($writer, 'item', 'ok');
    xmlwriter_end_element($writer);
    if (xmlwriter_output_memory($writer) !== '<root><item>ok</item></root>') {
        exit('XMLWRITER_FAIL');
    }
    exit('DOM_XMLWRITER_OK');
}

$writer = xmlwriter_open_memory();
xmlwriter_start_element($writer, 'root');
$input = file_get_contents('/tmp/xmlwriter-large.txt');
xmlwriter_text($writer, $input);
unset($input);
xmlwriter_end_element($writer);
ini_set('memory_limit', '8M');
echo "READY\n";
$output = xmlwriter_output_memory($writer);
echo "RETURNED\n";
