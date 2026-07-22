<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ClienteVendedor extends Model
{
    use HasFactory;

    protected $table = 'clientes_vendedor';

    protected $fillable = [
        'vendedor_id',
        'nombre',
        'telefono',
        'direccion',
        'activo',
    ];
}
