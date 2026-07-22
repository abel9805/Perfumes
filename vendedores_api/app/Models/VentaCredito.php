<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VentaCredito extends Model
{
    use HasFactory;

    protected $table = 'ventas_credito';

    protected $fillable = [
        'cliente_id',
        'vendedor_id',
        'fecha',
        'fecha_primer_pago',
        'monto_total',
        'monto_pagado',
        'estado',
        'cantidad_pagos',
        'frecuencia_pago',
        'notas',
    ];
}
