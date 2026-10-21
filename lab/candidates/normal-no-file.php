<?php
header('Content-Type: text/plain');

if (!isset($_POST['title']) || $_POST['title'] !== 'ordinary' || !empty($_FILES)) {
    http_response_code(400);
    echo "NO_FILE_FAIL\n";
    exit;
}

echo "NO_FILE_OK\n";
