<?php
function echoText($value) {
    return $value;
}
$server = new SoapServer(null, ['uri' => 'urn:backport-normal']);
$server->addFunction('echoText');
$server->handle();
