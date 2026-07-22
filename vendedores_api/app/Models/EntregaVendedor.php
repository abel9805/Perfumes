<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EntregaVendedor extends Model
{
    use HasFactory;

    protected $table = 'entregas_vendedor';

    protected $fillable = [
        'vendedor_id',
        'perfume_id',
        'tipo',
        'cantidad',
        'precio_unitario',
        'fecha',
        'estado',
    ];
}
