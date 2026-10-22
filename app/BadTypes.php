<?php

namespace App;

class BadTypes
{
    public function run(): int
    {
        return $this->doesNotExist();
    }
}
