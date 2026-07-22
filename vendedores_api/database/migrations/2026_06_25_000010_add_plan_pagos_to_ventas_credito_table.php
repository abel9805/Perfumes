<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ventas_credito', function (Blueprint $table) {
            $table->unsignedInteger('cantidad_pagos')->default(1)->after('estado');
            $table->string('frecuencia_pago', 30)->default('quincenal')->after('cantidad_pagos');
        });
    }

    public function down(): void
    {
        Schema::table('ventas_credito', function (Blueprint $table) {
            $table->dropColumn(['cantidad_pagos', 'frecuencia_pago']);
        });
    }
};
