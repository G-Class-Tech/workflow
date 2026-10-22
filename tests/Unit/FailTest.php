<?php

namespace Tests\Unit;

use PHPUnit\Framework\TestCase;

class FailTest extends TestCase
{
    public function test_fails(): void
    {
        $this->assertTrue(false);
    }
}
