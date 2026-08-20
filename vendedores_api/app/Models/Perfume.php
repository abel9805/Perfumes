<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Perfume extends Model
{
    use HasFactory;

    protected $table = 'perfumes';

    protected $fillable = [
        'nombre',
        'marca',
        'mililitros',
        'concentracion',
        'descripcion',
        'precio_costo',
        'precio_venta',
        'stock',
        'imagen',
    ];
}
