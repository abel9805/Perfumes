<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VentaVendedor extends Model
{
    use HasFactory;

    protected $table = 'ventas_vendedor';

    protected $fillable = [
        'vendedor_id',
        'cliente_id',
        'perfume_id',
        'cantidad',
        'precio_unitario',
        'total',
        'fecha',
        'tipo_pago',
        'estado_pago',
        'saldo_pendiente',
    ];
}
