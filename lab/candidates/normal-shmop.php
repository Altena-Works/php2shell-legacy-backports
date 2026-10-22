<?php
header('Content-Type: text/plain');

if (isset($_GET['limit'])) {
    ini_set('memory_limit', '8M');
    $large = shmop_open(0, 'c', 0600, 12 * 1024 * 1024);
    if ($large === false) {
        echo "SHMOP_SETUP_FAIL\n";
        return;
    }
    shmop_delete($large);
    echo "READY\n";
    shmop_read($large, 0, 12 * 1024 * 1024);
    echo "RETURNED\n";
    return;
}

$shm = shmop_open(0, 'c', 0600, 64);
if ($shm === false) {
    echo "SHMOP_FAIL\n";
    return;
}

$written = shmop_write($shm, 'safe-check', 0);
$read = shmop_read($shm, 0, 10);
shmop_delete($shm);
shmop_close($shm);
echo $written === 10 && $read === 'safe-check' ? "SHMOP_OK\n" : "SHMOP_FAIL\n";
