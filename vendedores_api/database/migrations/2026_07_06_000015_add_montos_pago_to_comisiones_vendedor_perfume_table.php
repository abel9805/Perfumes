<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('comisiones_vendedor_perfume', function (Blueprint $table) {
            $table->decimal('monto_por_confirmar', 12, 2)
                ->default(0)
                ->after('fecha_cobro_vendedor');
            $table->decimal('monto_cobrado', 12, 2)
                ->default(0)
                ->after('monto_por_confirmar');
        });
    }

    public function down(): void
    {
        Schema::table('comisiones_vendedor_perfume', function (Blueprint $table) {
            $table->dropColumn([
                'monto_por_confirmar',
                'monto_cobrado',
            ]);
        });
    }
};
