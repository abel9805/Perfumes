<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('entregas_vendedor', 'tipo')) {
            Schema::table('entregas_vendedor', function (Blueprint $table) {
                $table->string('tipo')->default('entrega')->after('perfume_id');
                $table->index(['tipo', 'estado']);
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('entregas_vendedor', 'tipo')) {
            Schema::table('entregas_vendedor', function (Blueprint $table) {
                $table->dropColumn('tipo');
            });
        }
    }
};