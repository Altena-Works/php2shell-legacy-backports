<?php
if (!extension_loaded('gd')) {
    echo "GD_MISSING\n";
    exit;
}

$mode = $_GET['mode'] ?? 'normal';
if ($mode === 'normal') {
    $image = imagecreate(16, 16);
    imagecolorallocate($image, 255, 255, 255);
    imagecolorallocate($image, 0, 0, 0);
    $path = '/tmp/backport-normal.wbmp';
    $written = imagewbmp($image, $path);
    imagedestroy($image);
    $loaded = $written ? imagecreatefromwbmp($path) : false;
    unlink($path);
    if (!$loaded || imagesx($loaded) !== 16 || imagesy($loaded) !== 16) {
        echo "WBMP_FAILED\n";
        exit;
    }
    imagedestroy($loaded);
    echo "WBMP_OK\n";
    exit;
}

$path = '/tmp/backport-large.wbmp';
if ($mode === 'seed') {
    $image = imagecreate(2048, 2048);
    imagecolorallocate($image, 255, 255, 255);
    $written = imagewbmp($image, $path);
    imagedestroy($image);
    echo $written ? "WBMP_SEEDED\n" : "WBMP_SEED_FAILED\n";
    exit;
}

if ($mode === 'read-limit') {
    if (!is_file($path) || ini_set('memory_limit', '8M') === false) {
        echo "SETUP_FAILED\n";
        exit;
    }
    echo "READY\n";
    imagecreatefromwbmp($path);
    echo "RETURNED\n";
    exit;
}

echo "UNKNOWN_MODE\n";
