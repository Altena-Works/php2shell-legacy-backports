<?php
$content = str_repeat('a', 12 * 1024 * 1024);
$response = '<?xml version="1.0" encoding="UTF-8"?>'
    . '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">'
    . '<soap:Body><echoTextResponse><return>' . $content
    . '</return></echoTextResponse></soap:Body></soap:Envelope>';
header('Content-Type: text/xml; charset=utf-8');
header('Content-Length: ' . strlen($response));
echo $response;
