<?php
if (!extension_loaded('xml')) {
    exit('XML_EXTENSION_MISSING');
}
if (isset($_GET['backend'])) {
    exit(XML_SAX_IMPL);
}

if (!isset($_GET['limit'])) {
    $events = array();
    $parser = xml_parser_create();
    xml_set_element_handler($parser,
        function ($parser, $name, $attributes) use (&$events) {
            $events[] = 'start:' . $name . ':' . $attributes['A'];
        },
        function ($parser, $name) use (&$events) {
            $events[] = 'end:' . $name;
        });
    xml_set_character_data_handler($parser,
        function ($parser, $data) use (&$events) {
            $events[] = 'text:' . $data;
        });
    if (!xml_parse($parser, '<root a="1">ok</root>', true)) {
        exit('XML_PARSE_FAIL');
    }
    xml_parser_free($parser);
    if ($events !== array('start:ROOT:1', 'text:ok', 'end:ROOT')) {
        exit('XML_HANDLER_FAIL');
    }
    $parser = xml_parser_create();
    $values = array();
    $index = array();
    if (!xml_parse_into_struct($parser, '<root><item a="1">ok</item></root>', $values, $index)) {
        exit('XML_STRUCT_FAIL');
    }
    xml_parser_free($parser);
    if (count($values) !== 3 || !isset($index['ITEM'])) {
        exit('XML_STRUCT_RESULT_FAIL');
    }
    exit('XML_SAX_OK');
}

$input = file_get_contents('/tmp/xml-sax-large.xml');
$parser = xml_parser_create();
$values = array();
$index = array();
ini_set('memory_limit', '8M');
echo "READY\n";
$status = xml_parse_into_struct($parser, $input, $values, $index);
echo "RETURNED\n";
