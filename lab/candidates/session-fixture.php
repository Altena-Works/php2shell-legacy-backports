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
    $_SESSION['fixture'] = new BackportSessionFixture();
    echo "SEEDED\n";
} else {
    echo isset($_SESSION['fixture'])
        && $_SESSION['fixture'] instanceof BackportSessionFixture
        && $_SESSION['fixture']->value() === 'ordinary'
        ? "PRESERVED\n" : "SESSION_VALUE_FAIL\n";
}
