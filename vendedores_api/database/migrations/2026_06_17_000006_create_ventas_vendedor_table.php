<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ventas_vendedor', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vendedor_id')->constrained('vendedores')->cascadeOnDelete();
            $table->foreignId('cliente_id')->constrained('clientes_vendedor')->cascadeOnDelete();
            $table->foreignId('perfume_id')->constrained('perfumes')->cascadeOnDelete();
            $table->integer('cantidad');
            $table->decimal('precio_unitario', 10, 2);
            $table->decimal('total', 10, 2);
            $table->date('fecha');
            $table->string('tipo_pago')->default('contado');
            $table->string('estado_pago')->default('pagado');
            $table->decimal('saldo_pendiente', 10, 2)->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ventas_vendedor');
    }
};
