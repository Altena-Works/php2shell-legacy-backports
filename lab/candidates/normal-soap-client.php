<?php
header('Content-Type: text/plain');
try {
    $client = new SoapClient(null, [
        'location' => 'http://127.0.0.1/normal-soap-server.php',
        'uri' => 'urn:backport-normal',
        'exceptions' => true,
    ]);
    $result = $client->__soapCall('echoText', ['ordinary']);
    if ($result !== 'ordinary') {
        throw new RuntimeException('unexpected response');
    }
    echo 'SOAP_OK';
} catch (Throwable $error) {
    http_response_code(500);
    echo 'SOAP_FAIL';
}
