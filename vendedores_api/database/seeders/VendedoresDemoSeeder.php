<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class VendedoresDemoSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('vendedores')->updateOrInsert(
            ['id' => 1],
            [
                'nombre' => 'Vendedor Demo',
                'telefono' => '99999999',
                'email' => 'vendedor@demo.local',
                'direccion' => 'Zona demo',
                'usuario' => 'vendedor.demo',
                'password' => '1234',
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );

        DB::table('perfumes')->updateOrInsert(
            ['id' => 1],
            [
                'nombre' => 'Perfume A',
                'marca' => 'Marca A',
                'descripcion' => null,
                'precio_costo' => 10,
                'precio_venta' => 15,
                'stock' => 100,
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );

        DB::table('perfumes')->updateOrInsert(
            ['id' => 2],
            [
                'nombre' => 'Perfume B',
                'marca' => 'Marca B',
                'descripcion' => null,
                'precio_costo' => 12,
                'precio_venta' => 18,
                'stock' => 80,
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );

        $existePendiente = DB::table('entregas_vendedor')
            ->where('vendedor_id', 1)
            ->where('perfume_id', 1)
            ->where('estado', 'pendiente_confirmacion')
            ->exists();

        if (!$existePendiente) {
            DB::table('entregas_vendedor')->insert([
                'vendedor_id' => 1,
                'perfume_id' => 1,
                'cantidad' => 5,
                'precio_unitario' => 15,
                'fecha' => now()->toDateString(),
                'estado' => 'pendiente_confirmacion',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $existeConfirmado = DB::table('entregas_vendedor')
            ->where('vendedor_id', 1)
            ->where('perfume_id', 2)
            ->where('estado', 'confirmado')
            ->exists();

        if (!$existeConfirmado) {
            DB::table('entregas_vendedor')->insert([
                'vendedor_id' => 1,
                'perfume_id' => 2,
                'cantidad' => 3,
                'precio_unitario' => 18,
                'fecha' => now()->toDateString(),
                'estado' => 'confirmado',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }
}
