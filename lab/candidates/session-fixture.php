<?php
class BackportSessionFixture implements Serializable {
    private $value = 'ordinary';

    public function serialize() {
        return $this->value;
    }

    public function unserialize($data) {
        $this->value = $data;
    }

    public function value() {
        return $this->value;
    }
}

header('Content-Type: text/plain');
if (!session_start()) {
    http_response_code(500);
    exit("SESSION_FAIL\n");
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_GET['reserved'])) {
        $object = new stdClass();
        $object->__PHP_Incomplete_Class_Name = 'name';
        $object->__PHP_Incomplete_Class_Serialized = 'serialized';
        $object->__PHP_Incomplete_Enum_Case = 'enum';
        $_SESSION['reserved'] = $object;
        echo "RESERVED_SEEDED\n";
        return;
    }
    $_SESSION['fixture'] = new BackportSessionFixture();
    echo "SEEDED\n";
} else {
    if (isset($_GET['reserved'])) {
        $object = isset($_SESSION['reserved']) ? $_SESSION['reserved'] : null;
        echo $object instanceof stdClass
            && $object->__PHP_Incomplete_Class_Name === 'name'
            && $object->__PHP_Incomplete_Class_Serialized === 'serialized'
            && $object->__PHP_Incomplete_Enum_Case === 'enum'
            ? "RESERVED_PRESERVED\n" : "RESERVED_LOST\n";
        echo isset($_SESSION['upload_progress_check'])
            ? "PROGRESS_PRESENT\n" : "PROGRESS_ABSENT\n";
        return;
    }
    echo isset($_SESSION['fixture'])
        && $_SESSION['fixture'] instanceof BackportSessionFixture
        && $_SESSION['fixture']->value() === 'ordinary'
        ? "PRESERVED\n" : "SESSION_VALUE_FAIL\n";
    if (isset($_GET['progress'])) {
        echo isset($_SESSION['upload_progress_check'])
            ? "PROGRESS_PRESENT\n" : "PROGRESS_ABSENT\n";
    }
}
