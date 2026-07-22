<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pagos_venta', function (Blueprint $table) {
            $table->string('comision_tipo', 20)->nullable()->after('notas');
            $table->decimal('comision_valor', 12, 2)->default(0)->after('comision_tipo');
            $table->decimal('comision_total', 12, 2)->default(0)->after('comision_valor');
        });
    }

    public function down(): void
    {
        Schema::table('pagos_venta', function (Blueprint $table) {
            $table->dropColumn(['comision_tipo', 'comision_valor', 'comision_total']);
        });
    }
};
