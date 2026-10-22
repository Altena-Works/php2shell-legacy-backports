<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
$client = new SoapClient(null, [
    'location' => 'http://127.0.0.1:8081/normal-soap-large-response.php',
    'uri' => 'urn:backport-normal',
    'exceptions' => true,
]);
$client->__soapCall('echoText', ['ordinary']);
echo 'RETURNED';
