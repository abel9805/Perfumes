<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ComisionVendedorPerfume extends Model
{
    use HasFactory;

    protected $table = 'comisiones_vendedor_perfume';

    protected $fillable = [
        'vendedor_id',
        'perfume_id',
        'comision_tipo',
        'comision_valor',
        'estado_pago',
        'fecha_pago_admin',
        'fecha_cobro_vendedor',
        'monto_por_confirmar',
        'monto_cobrado',
    ];
}
