<?php
class BackportUnserializeFixture {
    public $value = 'ordinary';
}

function backport_unserialize_define_class($name) {
    if ($name === 'BackportCallbackFixture') {
        class BackportCallbackFixture {
            public $value = 'callback';
        }
    }
}

header('Content-Type: text/plain');
$key = str_repeat('key', 100);
$serialized = serialize([$key => new BackportUnserializeFixture()]);
$allowed = unserialize($serialized, ['allowed_classes' => ['backportunserializefixture']]);
$blocked = unserialize($serialized, ['allowed_classes' => false]);
ini_set('unserialize_callback_func', 'backport_unserialize_define_class');
$callbackName = 'BackportCallbackFixture';
$callbackSerialized = sprintf('O:%d:"%s":0:{}', strlen($callbackName), $callbackName);
$callback = unserialize($callbackSerialized);
$ok = isset($allowed[$key]) && $allowed[$key] instanceof BackportUnserializeFixture
    && $allowed[$key]->value === 'ordinary'
    && isset($blocked[$key]) && get_class($blocked[$key]) === '__PHP_Incomplete_Class'
    && $callback instanceof BackportCallbackFixture && $callback->value === 'callback';
echo $ok ? "UNSERIALIZE_OK\n" : "UNSERIALIZE_FAIL\n";
