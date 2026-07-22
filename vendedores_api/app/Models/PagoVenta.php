<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PagoVenta extends Model
{
    use HasFactory;

    protected $table = 'pagos_venta';

    protected $fillable = [
        'venta_id',
        'monto',
        'fecha',
        'notas',
        'comision_tipo',
        'comision_valor',
        'comision_total',
    ];
}
