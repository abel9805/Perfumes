<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('comisiones_vendedor_perfume', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vendedor_id')->constrained('vendedores')->cascadeOnDelete();
            $table->foreignId('perfume_id')->constrained('perfumes')->cascadeOnDelete();
            $table->string('comision_tipo', 20);
            $table->decimal('comision_valor', 12, 2);
            $table->timestamps();

            $table->unique(['vendedor_id', 'perfume_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('comisiones_vendedor_perfume');
    }
};
