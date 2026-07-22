<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ventas_credito', function (Blueprint $table) {
            $table->date('fecha_primer_pago')->nullable()->after('fecha');
        });
    }

    public function down(): void
    {
        Schema::table('ventas_credito', function (Blueprint $table) {
            $table->dropColumn('fecha_primer_pago');
        });
    }
};
