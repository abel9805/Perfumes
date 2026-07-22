<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pagos_venta_vendedor', function (Blueprint $table) {
            $table->string('estado', 30)
                ->default('pendiente_confirmacion')
                ->after('nota');
            $table->timestamp('fecha_confirmacion')
                ->nullable()
                ->after('estado');
        });
    }

    public function down(): void
    {
        Schema::table('pagos_venta_vendedor', function (Blueprint $table) {
            $table->dropColumn(['estado', 'fecha_confirmacion']);
        });
    }
};
