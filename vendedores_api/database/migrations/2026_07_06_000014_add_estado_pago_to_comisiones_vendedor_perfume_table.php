<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('comisiones_vendedor_perfume', function (Blueprint $table) {
            $table->string('estado_pago', 20)
                ->default('por_pagar')
                ->after('comision_valor');
            $table->timestamp('fecha_pago_admin')
                ->nullable()
                ->after('estado_pago');
            $table->timestamp('fecha_cobro_vendedor')
                ->nullable()
                ->after('fecha_pago_admin');
        });
    }

    public function down(): void
    {
        Schema::table('comisiones_vendedor_perfume', function (Blueprint $table) {
            $table->dropColumn([
                'estado_pago',
                'fecha_pago_admin',
                'fecha_cobro_vendedor',
            ]);
        });
    }
};
