<?php
if (!isset($_GET['limit'])) {
    $array = SplFixedArray::fromArray([2 => 'two']);
    $array->setSize(5);
    $copy = clone $array;
    $copy->setSize(2);
    echo $array->getSize() === 5 && $copy->getSize() === 2 && $array[2] === 'two'
        ? 'SPL_OK' : 'SPL_BAD';
    return;
}

ini_set('memory_limit', '8M');
echo 'READY';
new SplFixedArray(1000000);
echo 'RETURNED';
