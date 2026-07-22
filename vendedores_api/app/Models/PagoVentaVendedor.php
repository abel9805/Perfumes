<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PagoVentaVendedor extends Model
{
    use HasFactory;

    protected $table = 'pagos_venta_vendedor';

    protected $fillable = [
        'venta_id',
        'monto',
        'fecha',
        'nota',
        'estado',
        'fecha_confirmacion',
    ];
}
