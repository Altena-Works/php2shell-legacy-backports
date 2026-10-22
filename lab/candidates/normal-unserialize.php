<?php
class BackportUnserializeFixture {
    public $value = 'ordinary';
}

header('Content-Type: text/plain');
$key = str_repeat('key', 100);
$serialized = serialize([$key => new BackportUnserializeFixture()]);
$allowed = unserialize($serialized, ['allowed_classes' => ['BackportUnserializeFixture']]);
$blocked = unserialize($serialized, ['allowed_classes' => false]);
$ok = isset($allowed[$key]) && $allowed[$key] instanceof BackportUnserializeFixture
    && $allowed[$key]->value === 'ordinary'
    && isset($blocked[$key]) && get_class($blocked[$key]) === '__PHP_Incomplete_Class';
echo $ok ? "UNSERIALIZE_OK\n" : "UNSERIALIZE_FAIL\n";
