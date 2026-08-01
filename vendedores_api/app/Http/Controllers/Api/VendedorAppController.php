<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cliente;
use App\Models\ComisionVendedorPerfume;
use App\Models\DetalleVenta;
use App\Models\EntregaVendedor;
use App\Models\PagoVenta;
use App\Models\PagoVentaVendedor;
use App\Models\Perfume;
use App\Models\Vendedor;
use App\Models\VentaCredito;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class VendedorAppController extends Controller
{
    public function saldoPorPagar(int $id): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $ventas = VentaCredito::query()
            ->where('vendedor_id', $id)
            ->whereRaw('monto_total > monto_pagado')
            ->orderByDesc('fecha')
            ->orderByDesc('id')
            ->get();

        if ($ventas->isEmpty()) {
            return response()->json([]);
        }

        $ventaIds = $ventas->pluck('id');

        $pendientesPorVenta = PagoVentaVendedor::query()
            ->whereIn('venta_id', $ventaIds)
            ->where('estado', 'pendiente_confirmacion')
            ->selectRaw('venta_id, COALESCE(SUM(monto), 0) as total')
            ->groupBy('venta_id')
            ->pluck('total', 'venta_id');

        $confirmadosPorVenta = PagoVentaVendedor::query()
            ->whereIn('venta_id', $ventaIds)
            ->where('estado', 'confirmado')
            ->selectRaw('venta_id, COALESCE(SUM(monto), 0) as total')
            ->groupBy('venta_id')
            ->pluck('total', 'venta_id');

        $abonosClientePorVenta = PagoVenta::query()
            ->whereIn('venta_id', $ventaIds)
            ->where(function ($q) {
                $q->whereNull('notas')
                    ->orWhere('notas', 'not like', 'Pago confirmado%');
            })
            ->selectRaw('venta_id, COALESCE(SUM(monto), 0) as total')
            ->groupBy('venta_id')
            ->pluck('total', 'venta_id');

        $rows = $ventas->map(function (VentaCredito $venta) use ($pendientesPorVenta, $confirmadosPorVenta, $abonosClientePorVenta) {
            $saldoActual = max(0, (float) $venta->monto_total - (float) $venta->monto_pagado);
            $pendienteConfirmar = (float) ($pendientesPorVenta[$venta->id] ?? 0);
            $confirmadoVendedor = (float) ($confirmadosPorVenta[$venta->id] ?? 0);
            $abonosCliente = (float) ($abonosClientePorVenta[$venta->id] ?? 0);

            $calculo = $this->calcularReglaPagoVendedor(
                $venta,
                $pendienteConfirmar,
                $confirmadoVendedor,
                $abonosCliente
            );

            return [
                'venta_id' => $venta->id,
                'fecha' => $venta->fecha,
                'fecha_primer_pago' => $calculo['fecha_primer_pago'],
                'cliente_id' => $venta->cliente_id,
                'nombre_cliente' => $venta->nombre_cliente,
                'monto_total' => (float) $venta->monto_total,
                'monto_pagado' => (float) $venta->monto_pagado,
                'saldo_pendiente' => $saldoActual,
                'cantidad_pagos' => $calculo['cantidad_pagos'],
                'cuotas_habilitadas_hoy' => $calculo['cuotas_habilitadas_hoy'],
                'monto_pago_correspondiente' => $calculo['monto_pago_correspondiente'],
                'monto_abonos_ventas' => $calculo['monto_abonos_ventas'],
                'monto_programado_regla' => $calculo['monto_programado_regla'],
                'monto_pendiente_confirmar' => $pendienteConfirmar,
                'monto_confirmado_vendedor' => $confirmadoVendedor,
                'monto_disponible_pagar' => $calculo['monto_disponible_pagar'],
            ];
        })->values();

        return response()->json($rows);
    }

    public function pagarSaldoPorVenta(Request $request, int $id, int $ventaId): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $data = $request->validate([
            'monto' => ['required', 'numeric', 'gt:0'],
            'fecha' => ['nullable', 'date'],
            'nota' => ['nullable', 'string', 'max:500'],
        ]);

        $venta = VentaCredito::query()
            ->where('id', $ventaId)
            ->where('vendedor_id', $id)
            ->first();

        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada para este vendedor'], 404);
        }

        $saldoActual = max(0, (float) $venta->monto_total - (float) $venta->monto_pagado);
        if ($saldoActual <= 0) {
            return response()->json(['message' => 'La venta ya esta pagada'], 422);
        }

        $pendienteConfirmar = (float) PagoVentaVendedor::query()
            ->where('venta_id', $venta->id)
            ->where('estado', 'pendiente_confirmacion')
            ->sum('monto');

        $confirmadoVendedor = (float) PagoVentaVendedor::query()
            ->where('venta_id', $venta->id)
            ->where('estado', 'confirmado')
            ->sum('monto');

        $abonosCliente = (float) PagoVenta::query()
            ->where('venta_id', $venta->id)
            ->where(function ($q) {
                $q->whereNull('notas')
                    ->orWhere('notas', 'not like', 'Pago confirmado%');
            })
            ->sum('monto');

        $calculo = $this->calcularReglaPagoVendedor(
            $venta,
            $pendienteConfirmar,
            $confirmadoVendedor,
            $abonosCliente
        );
        $montoDisponible = (float) $calculo['monto_disponible_pagar'];
        $montoSolicitado = round((float) $data['monto'], 2);

        if ($montoSolicitado <= 0) {
            return response()->json(['message' => 'Monto invalido'], 422);
        }

        if ($montoSolicitado > $montoDisponible) {
            return response()->json([
                'message' => 'El monto excede el saldo disponible para confirmar',
                'monto_disponible' => $montoDisponible,
            ], 422);
        }

        $pago = PagoVentaVendedor::create([
            'venta_id' => $venta->id,
            'monto' => $montoSolicitado,
            'fecha' => $data['fecha'] ?? Carbon::today()->toDateString(),
            'nota' => $data['nota'] ?? null,
            'estado' => 'pendiente_confirmacion',
        ]);

        return response()->json([
            'message' => 'Pago enviado a confirmacion de admin',
            'monto_disponible' => $montoDisponible,
            'pago' => $pago,
        ], 201);
    }

    private function calcularReglaPagoVendedor(
        VentaCredito $venta,
        float $pendienteConfirmar,
        float $confirmadoVendedor,
        float $abonosCliente
    ): array {
        $montoTotal = max(0, round((float) $venta->monto_total, 2));
        $montoPagado = max(0, round((float) $venta->monto_pagado, 2));
        $saldoActual = max(0, round($montoTotal - $montoPagado, 2));

        $cantidadPagos = max(1, (int) ($venta->cantidad_pagos ?? 1));
        $fechaPrimerPago = $venta->fecha_primer_pago
            ? Carbon::parse((string) $venta->fecha_primer_pago)->startOfDay()
            : Carbon::parse($this->nextPaymentCutoffOnOrAfter((string) $venta->fecha))->startOfDay();

        $cuotasHabilitadas = $this->cuotasHabilitadasHastaHoy($fechaPrimerPago, $cantidadPagos);
        $montoPagoCorrespondiente = round(min($montoTotal, ($montoTotal / $cantidadPagos) * $cuotasHabilitadas), 2);
        $montoAbonosVentas = round(min($montoTotal, max(0, $abonosCliente)), 2);
        $montoProgramadoRegla = round(min($montoTotal, $montoPagoCorrespondiente + $montoAbonosVentas), 2);

        $montoProgramadoNeto = max(0, round($montoProgramadoRegla - $confirmadoVendedor - $pendienteConfirmar, 2));
        $montoDisponibleSaldo = max(0, round($saldoActual - $pendienteConfirmar, 2));
        $montoDisponiblePagar = round(min($montoDisponibleSaldo, $montoProgramadoNeto), 2);

        return [
            'fecha_primer_pago' => $fechaPrimerPago->toDateString(),
            'cantidad_pagos' => $cantidadPagos,
            'cuotas_habilitadas_hoy' => $cuotasHabilitadas,
            'monto_pago_correspondiente' => $montoPagoCorrespondiente,
            'monto_abonos_ventas' => $montoAbonosVentas,
            'monto_programado_regla' => $montoProgramadoRegla,
            'monto_disponible_pagar' => $montoDisponiblePagar,
        ];
    }

    private function cuotasHabilitadasHastaHoy(Carbon $fechaPrimerPago, int $cantidadPagos): int
    {
        $hoy = Carbon::today();
        $cursor = $fechaPrimerPago->copy()->startOfDay();
        $habilitadas = 0;

        for ($i = 0; $i < $cantidadPagos; $i++) {
            if ($cursor->lte($hoy)) {
                $habilitadas++;
            }

            $cursor = $this->nextQuincenalCutoff($cursor);
        }

        return $habilitadas;
    }

    private function nextQuincenalCutoff(Carbon $fecha): Carbon
    {
        $d = $fecha->copy()->startOfDay();
        $last = $d->copy()->endOfMonth()->day;

        if ($d->day < 15) {
            return $d->day(15);
        }

        if ($d->day < $last) {
            return $d->day($last);
        }

        return $d->addMonthNoOverflow()->day(15);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'usuario' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        $vendedor = Vendedor::where('usuario', $data['usuario'])->first();

        if (!$vendedor || (string) $vendedor->password !== $data['password']) {
            return response()->json([
                'message' => 'Credenciales invalidas',
            ], 401);
        }

        return response()->json($this->vendedorPayload($vendedor));
    }

    public function informacion(int $id): JsonResponse
    {
        $vendedor = $this->findVendedorOrFail($id);

        return response()->json($this->vendedorPayload($vendedor));
    }

    public function pendientes(Request $request, int $id): JsonResponse
    {
        $tipo = $request->query('tipo', 'entrega');
        $query = DB::table('entregas_vendedor as e')
            ->join('perfumes as p', 'p.id', '=', 'e.perfume_id')
            ->where('e.vendedor_id', $id)
            ->whereIn('e.estado', ['pendiente', 'pendiente_confirmacion'])
            ->orderByDesc('e.fecha');

        if (is_string($tipo) && $tipo !== '' && $tipo !== 'todos') {
            $query->where('e.tipo', $tipo);
        } else {
            $query->whereIn('e.tipo', ['entrega', 'inicial', 'pedido']);
        }

        $rows = $query->get([
                'e.id',
                'e.tipo',
                'e.vendedor_id',
                'e.perfume_id',
                'e.cantidad',
                'e.precio_unitario',
                'e.fecha',
                'e.estado',
                DB::raw('p.nombre as nombre_perfume'),
            ]);

        return response()->json($rows);
    }

    public function pedidos(int $id): JsonResponse
    {
        $rows = DB::table('entregas_vendedor as e')
            ->join('perfumes as p', 'p.id', '=', 'e.perfume_id')
            ->where('e.vendedor_id', $id)
            ->where('e.tipo', 'pedido')
            ->whereIn('e.estado', ['solicitado', 'pendiente_confirmacion', 'confirmado', 'pagado'])
            ->orderByDesc('e.fecha')
            ->orderByDesc('e.id')
            ->get([
                'e.id',
                'e.tipo',
                'e.vendedor_id',
                'e.perfume_id',
                'e.cantidad',
                'e.precio_unitario',
                'e.fecha',
                'e.estado',
                DB::raw('p.nombre as nombre_perfume'),
                DB::raw('p.marca as marca_perfume'),
            ]);

        return response()->json($rows);
    }

    public function catalogoPedidos(int $id): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $rows = Perfume::query()
            ->orderBy('nombre')
            ->get(['id', 'nombre', 'marca', 'mililitros', 'concentracion', 'descripcion', 'precio_venta', 'stock', 'imagen']);

        return response()->json($rows->map(function (Perfume $perfume) {
            $imagen = $perfume->imagen ?? null;

            return [
                'perfume_id' => $perfume->id,
                'nombre_perfume' => $perfume->nombre,
                'marca_perfume' => $perfume->marca,
                'mililitros' => $perfume->mililitros,
                'concentracion' => $perfume->concentracion,
                'descripcion_perfume' => $perfume->descripcion,
                'precio_venta' => $perfume->precio_venta,
                'stock' => $perfume->stock,
                'imagen' => $imagen,
                'imagen_url' => $imagen ? url('storage/' . $imagen) : null,
            ];
        })->values());
    }

    public function storePedido(Request $request, int $id): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $data = $request->validate([
            'fecha' => ['required', 'date'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
            'items.*.cantidad' => ['required', 'integer', 'min:1'],
            'items.*.precio_unitario' => ['required', 'numeric', 'min:0'],
        ]);

        $pedidos = DB::transaction(function () use ($data, $id) {
            $rows = [];
            foreach ($data['items'] as $item) {
                $rows[] = EntregaVendedor::create([
                    'vendedor_id' => $id,
                    'perfume_id' => (int) $item['perfume_id'],
                    'tipo' => 'pedido',
                    'cantidad' => (int) $item['cantidad'],
                    'precio_unitario' => (float) $item['precio_unitario'],
                    'fecha' => $data['fecha'],
                    'estado' => 'solicitado',
                ]);
            }

            return $rows;
        });

        return response()->json([
            'message' => 'Pedido solicitado correctamente',
            'items' => $pedidos,
        ], 201);
    }

    public function confirmarEntrega(int $entregaId): JsonResponse
    {
        $entrega = EntregaVendedor::find($entregaId);
        if (!$entrega) {
            return response()->json(['message' => 'Entrega no encontrada'], 404);
        }

        if ($entrega->estado === 'solicitado') {
            return response()->json([
                'message' => 'El pedido aún no fue surtido por admin',
                'entrega_id' => $entrega->id,
            ], 409);
        }

        if (in_array($entrega->estado, ['confirmado', 'pagado'], true)) {
            return response()->json([
                'message' => 'Entrega ya confirmada',
                'entrega_id' => $entrega->id,
            ]);
        }

        $entrega->estado = 'confirmado';
        $entrega->save();

        return response()->json([
            'message' => 'Entrega confirmada',
            'entrega_id' => $entrega->id,
            'estado' => $entrega->estado,
        ]);
    }

    public function stock(int $id): JsonResponse
    {
        $tipo = request()->query('tipo', 'todos');
        $rows = $this->buildStockDisponibleQuery($id, is_string($tipo) ? $tipo : 'todos')->get();

        return response()->json($rows->map(function ($row) {
            $imagen = $row->imagen ?? null;
            $tiposOrigen = collect(explode(',', (string) ($row->tipos_origen ?? '')))
                ->map(fn ($t) => trim($t))
                ->filter(fn ($t) => $t !== '')
                ->values();
            return [
                'perfume_id' => (int) $row->perfume_id,
                'nombre_perfume' => $row->nombre_perfume,
                'marca_perfume' => $row->marca_perfume,
                'descripcion_perfume' => $row->descripcion_perfume,
                'precio_venta' => $row->precio_venta,
                'cantidad' => $row->cantidad,
                'tipos_origen' => $tiposOrigen,
                'imagen' => $imagen,
                'imagen_url' => $imagen ? url('storage/' . $imagen) : null,
            ];
        })->values());
    }

    public function perfumesDisponibles(int $id): JsonResponse
    {
        $rows = $this->buildStockDisponibleQuery($id)
            ->havingRaw('COALESCE(SUM(e.cantidad), 0) - COALESCE((SELECT SUM(dv.cantidad) FROM detalles_venta dv JOIN ventas_credito vv ON vv.id = dv.venta_id WHERE vv.vendedor_id = ? AND dv.perfume_id = p.id), 0) > 0', [$id])
            ->get();

        return response()->json($rows->map(function ($row) {
            $imagen = $row->imagen ?? null;
            $tiposOrigen = collect(explode(',', (string) ($row->tipos_origen ?? '')))
                ->map(fn ($t) => trim($t))
                ->filter(fn ($t) => $t !== '')
                ->values();
            return [
                'perfume_id' => (int) $row->perfume_id,
                'nombre_perfume' => $row->nombre_perfume,
                'marca_perfume' => $row->marca_perfume,
                'descripcion_perfume' => $row->descripcion_perfume,
                'precio_venta' => $row->precio_venta,
                'cantidad' => $row->cantidad,
                'tipos_origen' => $tiposOrigen,
                'imagen' => $imagen,
                'imagen_url' => $imagen ? url('storage/' . $imagen) : null,
            ];
        })->values());
    }

    public function clientes(int $id): JsonResponse
    {
        $rows = Cliente::query()
            ->where('vendedor_id', $id)
            ->orderBy('nombre')
            ->get();

        return response()->json($rows);
    }

    public function storeCliente(Request $request, int $id): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'telefono' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'direccion' => ['nullable', 'string'],
        ]);

        $cliente = Cliente::create([
            'vendedor_id' => $id,
            'nombre' => $data['nombre'],
            'telefono' => $data['telefono'] ?? null,
            'email' => $data['email'] ?? null,
            'direccion' => $data['direccion'] ?? null,
        ]);

        return response()->json($cliente, 201);
    }

    public function updateCliente(Request $request, int $id, int $clienteId): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $cliente = Cliente::query()
            ->where('id', $clienteId)
            ->where('vendedor_id', $id)
            ->first();

        if (!$cliente) {
            return response()->json(['message' => 'Cliente no encontrado'], 404);
        }

        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'telefono' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'direccion' => ['nullable', 'string'],
        ]);

        $cliente->update([
            'nombre' => $data['nombre'],
            'telefono' => $data['telefono'] ?? null,
            'email' => $data['email'] ?? null,
            'direccion' => $data['direccion'] ?? null,
        ]);

        return response()->json($cliente);
    }

    public function destroyCliente(int $id, int $clienteId): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $cliente = Cliente::query()
            ->where('id', $clienteId)
            ->where('vendedor_id', $id)
            ->first();

        if (!$cliente) {
            return response()->json(['message' => 'Cliente no encontrado'], 404);
        }

        if ($this->clienteTieneVentasPendientes((int) $cliente->id, $id)) {
            return response()->json([
                'message' => 'No se puede eliminar el cliente porque tiene ventas a credito pendientes',
            ], 409);
        }

        $cliente->delete();

        return response()->json(['message' => 'Cliente eliminado correctamente']);
    }

    public function ventas(int $id): JsonResponse
    {
        $rows = DB::table('ventas_credito as v')
            ->join('clientes as c', 'c.id', '=', 'v.cliente_id')
            ->where('v.vendedor_id', $id)
            ->orderByDesc('v.fecha')
            ->orderByDesc('v.id')
            ->get([
                'v.id',
                'v.cliente_id',
                'v.vendedor_id',
                'v.fecha',
                'v.fecha_primer_pago',
                'v.monto_total',
                'v.monto_pagado',
                'v.estado',
                'v.cantidad_pagos',
                'v.frecuencia_pago',
                'v.notas',
                DB::raw('c.nombre as nombre_cliente'),
                DB::raw('(v.monto_total - v.monto_pagado) as saldo_pendiente'),
            ]);

        return response()->json($rows);
    }

    public function comisiones(int $id): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $rows = DB::table('detalles_venta as d')
            ->join('ventas_credito as v', 'v.id', '=', 'd.venta_id')
            ->join('perfumes as p', 'p.id', '=', 'd.perfume_id')
            ->leftJoin('comisiones_vendedor_perfume as cp', function ($join) {
                $join->on('cp.vendedor_id', '=', 'v.vendedor_id')
                    ->on('cp.perfume_id', '=', 'd.perfume_id');
            })
            ->where('v.vendedor_id', $id)
            ->groupBy(
                'd.perfume_id',
                'p.nombre',
                'p.marca',
                'p.precio_venta',
                'cp.estado_pago',
                'cp.fecha_pago_admin',
                'cp.fecha_cobro_vendedor',
                'cp.monto_por_confirmar',
                'cp.monto_cobrado'
            )
            ->orderBy('p.nombre')
            ->get([
                DB::raw('d.perfume_id as perfume_id'),
                DB::raw('p.nombre as nombre_perfume'),
                DB::raw('p.marca as marca_perfume'),
                DB::raw('p.precio_venta as precio_lista'),
                DB::raw('SUM(d.cantidad) as cantidad_vendida'),
                DB::raw('SUM(d.cantidad * d.precio_unitario) as monto_vendido'),
                DB::raw('SUM(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) <= CURDATE() THEN d.cantidad ELSE 0 END) as cantidad_habilitada_comision'),
                DB::raw('SUM(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) <= CURDATE() THEN (d.cantidad * d.precio_unitario) ELSE 0 END) as monto_habilitado_comision'),
                DB::raw('MIN(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) > CURDATE() THEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) ELSE NULL END) as proxima_fecha_comision'),
                DB::raw('COALESCE(cp.monto_por_confirmar, 0) as comision_recibida'),
                DB::raw('COALESCE(cp.monto_cobrado, 0) as comision_cobrada'),
                DB::raw('cp.fecha_pago_admin as fecha_pago_admin'),
                DB::raw('cp.fecha_cobro_vendedor as fecha_cobro_vendedor'),
            ]);

        $rows = $rows->map(function ($row) {
            $precioLista = (float) ($row->precio_lista ?? 0);
            $comisionValor = $this->comisionFijaPorPrecioLista($precioLista);
            $cantidadHabilitada = (float) ($row->cantidad_habilitada_comision ?? 0);
            $comisionHabilitada = round($cantidadHabilitada * $comisionValor, 2);
            $comisionRecibida = (float) ($row->comision_recibida ?? 0);
            $comisionCobrada = (float) ($row->comision_cobrada ?? 0);

            $estadoPago = 'por_pagar';
            if ($comisionRecibida > 0) {
                $estadoPago = 'por_confirmar';
            } elseif ($comisionCobrada > 0) {
                $estadoPago = 'cobrado';
            }

            return [
                'perfume_id' => (int) $row->perfume_id,
                'nombre_perfume' => $row->nombre_perfume,
                'marca_perfume' => $row->marca_perfume,
                'precio_lista' => $precioLista,
                'cantidad_vendida' => (int) ($row->cantidad_vendida ?? 0),
                'monto_vendido' => (float) ($row->monto_vendido ?? 0),
                'cantidad_habilitada_comision' => (int) ($row->cantidad_habilitada_comision ?? 0),
                'monto_habilitado_comision' => (float) ($row->monto_habilitado_comision ?? 0),
                'proxima_fecha_comision' => $row->proxima_fecha_comision,
                'comision_tipo' => 'rango_precio',
                'comision_valor' => $comisionValor,
                'comision_habilitada' => $comisionHabilitada,
                'comision_recibida' => $comisionRecibida,
                'comision_cobrada' => $comisionCobrada,
                'fecha_pago_admin' => $row->fecha_pago_admin,
                'fecha_cobro_vendedor' => $row->fecha_cobro_vendedor,
                'estado_pago' => $estadoPago,
            ];
        })->values();

        $totalComision = (float) $rows->sum(function ($row) {
            return (float) ($row->comision_recibida ?? 0);
        });

        return response()->json([
            'items' => $rows,
            'total_comisiones' => round($totalComision, 2),
        ]);
    }

    public function cobrarComision(Request $request, int $id): JsonResponse
    {
        $this->findVendedorOrFail($id);

        $data = $request->validate([
            'perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
        ]);

        $comision = ComisionVendedorPerfume::query()
            ->where('vendedor_id', $id)
            ->where('perfume_id', (int) $data['perfume_id'])
            ->first();

        if (!$comision) {
            return response()->json([
                'message' => 'No hay comisión pendiente para este perfume',
            ], 404);
        }

        $montoPorConfirmar = (float) ($comision->monto_por_confirmar ?? 0);
        if ($montoPorConfirmar <= 0) {
            return response()->json([
                'message' => 'La comisión no está pendiente por confirmar',
            ], 409);
        }

        $comision->estado_pago = 'cobrado';
        $comision->monto_cobrado = round(
            (float) ($comision->monto_cobrado ?? 0) + $montoPorConfirmar,
            2
        );
        $comision->monto_por_confirmar = 0;
        $comision->fecha_cobro_vendedor = Carbon::now();
        $comision->save();

        return response()->json([
            'message' => 'Comisión cobrada correctamente',
            'item' => $comision,
        ]);
    }

    public function storeVenta(Request $request, int $id): JsonResponse
    {
        $vendedor = $this->findVendedorOrFail($id);

        $data = $request->validate([
            'cliente_id' => ['required', 'integer', 'exists:clientes,id'],
            'tipo_venta' => ['nullable', 'string', 'in:contado,credito'],
            'fecha' => ['required', 'date'],
            'fecha_primer_pago' => ['nullable', 'date'],
            'notas' => ['nullable', 'string'],
            'cantidad_pagos' => ['nullable', 'integer', 'min:1', 'max:24'],
            'frecuencia_pago' => ['nullable', 'string', 'in:quincenal'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
            'items.*.cantidad' => ['required', 'integer', 'min:1'],
            'items.*.precio_unitario' => ['required', 'numeric', 'min:0'],
        ]);

        $cliente = Cliente::query()
            ->where('id', $data['cliente_id'])
            ->where('vendedor_id', $id)
            ->first();

        if (!$cliente) {
            return response()->json(['message' => 'Cliente no válido para este vendedor'], 422);
        }

        foreach ($data['items'] as $item) {
            $disponible = $this->stockDisponiblePerfume($id, (int) $item['perfume_id']);
            if ((int) $item['cantidad'] > $disponible) {
                return response()->json([
                    'message' => 'Stock insuficiente para uno de los perfumes',
                    'perfume_id' => (int) $item['perfume_id'],
                    'stock_disponible' => $disponible,
                ], 422);
            }
        }

        $tipoVenta = $this->resolverTipoVenta($data);

        $venta = DB::transaction(function () use ($data, $id, $vendedor, $tipoVenta) {
            $perfumesById = Perfume::query()
                ->whereIn('id', collect($data['items'])->pluck('perfume_id')->all())
                ->get()
                ->keyBy('id');

            $montoTotal = 0.0;
            $detalles = [];

            foreach ($data['items'] as $item) {
                $perfumeId = (int) $item['perfume_id'];
                $cantidad = (int) $item['cantidad'];
                $perfume = $perfumesById->get($perfumeId);
                if (!$perfume) {
                    abort(422, 'Perfume no valido en items');
                }

                $precioUnitario = $this->precioConDescuentoEmbajador((float) $perfume->precio_venta, $vendedor, $tipoVenta);
                $detalles[] = [
                    'perfume_id' => $perfumeId,
                    'cantidad' => $cantidad,
                    'precio_unitario' => $precioUnitario,
                ];
                $montoTotal += $cantidad * $precioUnitario;
            }

            $montoTotal = round($montoTotal, 2);

            $venta = VentaCredito::create([
                'cliente_id' => (int) $data['cliente_id'],
                'vendedor_id' => $id,
                'fecha' => $data['fecha'],
                'fecha_primer_pago' => $data['fecha_primer_pago']
                    ?? $this->nextPaymentCutoffOnOrAfter($data['fecha']),
                'monto_total' => $montoTotal,
                'monto_pagado' => 0,
                'estado' => 'pendiente',
                'cantidad_pagos' => (int) ($data['cantidad_pagos'] ?? 1),
                'frecuencia_pago' => (string) ($data['frecuencia_pago'] ?? 'quincenal'),
                'notas' => $data['notas'] ?? null,
            ]);

            foreach ($detalles as $item) {
                DetalleVenta::create([
                    'venta_id' => $venta->id,
                    'perfume_id' => (int) $item['perfume_id'],
                    'cantidad' => (int) $item['cantidad'],
                    'precio_unitario' => (float) $item['precio_unitario'],
                ]);
            }

            return $venta;
        });

        return response()->json($venta, 201);
    }

    public function detallesVenta(int $id, int $ventaId): JsonResponse
    {
        $venta = VentaCredito::query()
            ->where('id', $ventaId)
            ->where('vendedor_id', $id)
            ->first();

        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada'], 404);
        }

        $rows = DB::table('detalles_venta as d')
            ->join('perfumes as p', 'd.perfume_id', '=', 'p.id')
            ->where('d.venta_id', $ventaId)
            ->orderBy('d.id')
            ->get([
                'd.id',
                'd.venta_id',
                'd.perfume_id',
                'd.cantidad',
                'd.precio_unitario',
                DB::raw('p.nombre as nombre_perfume'),
            ]);

        return response()->json($rows);
    }

    public function pagosVenta(int $id, int $ventaId): JsonResponse
    {
        $venta = VentaCredito::query()
            ->where('id', $ventaId)
            ->where('vendedor_id', $id)
            ->first();

        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada'], 404);
        }

        $rows = PagoVenta::query()
            ->where('venta_id', $ventaId)
            ->orderByDesc('fecha')
            ->orderByDesc('id')
            ->get();

        return response()->json($rows);
    }

    public function storePagoVenta(Request $request, int $id, int $ventaId): JsonResponse
    {
        $venta = VentaCredito::query()
            ->where('id', $ventaId)
            ->where('vendedor_id', $id)
            ->first();

        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada'], 404);
        }

        $data = $request->validate([
            'monto' => ['required', 'numeric', 'min:0.01'],
            'fecha' => ['required', 'date'],
            'notas' => ['nullable', 'string'],
        ]);

        $saldoPendiente = ((float) $venta->monto_total) - ((float) $venta->monto_pagado);
        if (((float) $data['monto']) > $saldoPendiente) {
            return response()->json(['message' => 'El monto excede el saldo pendiente'], 422);
        }

        $pago = DB::transaction(function () use ($venta, $data) {
            $pago = PagoVenta::create([
                'venta_id' => $venta->id,
                'monto' => (float) $data['monto'],
                'fecha' => $data['fecha'],
                'notas' => $data['notas'] ?? null,
                'comision_tipo' => null,
                'comision_valor' => 0,
                'comision_total' => 0,
            ]);

            $venta->monto_pagado = ((float) $venta->monto_pagado) + ((float) $data['monto']);
            if ((float) $venta->monto_pagado >= (float) $venta->monto_total) {
                $venta->estado = 'pagado';
            } elseif ((float) $venta->monto_pagado > 0) {
                $venta->estado = 'parcial';
            } else {
                $venta->estado = 'pendiente';
            }
            $venta->save();

            return $pago;
        });

        return response()->json($pago, 201);
    }

    private function buildStockDisponibleQuery(int $vendedorId, string $tipo = 'todos')
    {
        $query = DB::table('entregas_vendedor as e')
            ->join('perfumes as p', 'p.id', '=', 'e.perfume_id')
            ->where('e.vendedor_id', $vendedorId)
            ->whereIn('e.estado', ['confirmado', 'pagado'])
            ->groupBy('p.id', 'p.nombre', 'p.marca', 'p.descripcion', 'p.precio_venta', 'p.imagen')
            ->orderBy('p.nombre')
            ->select([
                DB::raw('p.id as perfume_id'),
                DB::raw('p.nombre as nombre_perfume'),
                DB::raw('p.marca as marca_perfume'),
                DB::raw('p.descripcion as descripcion_perfume'),
                DB::raw('p.precio_venta as precio_venta'),
                DB::raw('p.imagen as imagen'),
                DB::raw("GROUP_CONCAT(DISTINCT e.tipo ORDER BY e.tipo SEPARATOR ',') as tipos_origen"),
                DB::raw('COALESCE(SUM(e.cantidad), 0) - COALESCE((SELECT SUM(dv.cantidad) FROM detalles_venta dv JOIN ventas_credito vv ON vv.id = dv.venta_id WHERE vv.vendedor_id = ' . $vendedorId . ' AND dv.perfume_id = p.id), 0) as cantidad'),
            ]);

        if ($tipo !== 'todos') {
            $query->where('e.tipo', $tipo);
        }

        return $query;
    }

    private function stockDisponiblePerfume(int $vendedorId, int $perfumeId): int
    {
        $row = $this->buildStockDisponibleQuery($vendedorId)
            ->where('p.id', $perfumeId)
            ->first();

        return max(0, (int) ($row->cantidad ?? 0));
    }

    private function nextPaymentCutoffOnOrAfter(string $date): string
    {
        $d = Carbon::parse($date)->startOfDay();
        $lastDay = $d->copy()->endOfMonth()->day;

        if ($d->day <= 15) {
            return $d->copy()->day(15)->toDateString();
        }

        return $d->copy()->day($lastDay)->toDateString();
    }

    private function clienteTieneVentasPendientes(int $clienteId, int $vendedorId): bool
    {
        return VentaCredito::query()
            ->where('cliente_id', $clienteId)
            ->where('vendedor_id', $vendedorId)
            ->where('estado', '!=', 'pagado')
            ->exists();
    }

    private function findVendedorOrFail(int $id): Vendedor
    {
        $vendedor = Vendedor::find($id);
        abort_if(!$vendedor, 404, 'Vendedor no encontrado');

        return $vendedor;
    }

    private function vendedorPayload(Vendedor $vendedor): array
    {
        $regla = $this->reglaEmbajador($vendedor, Carbon::today());
        $resumenVentas = $this->resumenVentasVendedor((int) $vendedor->id);

        return [
            'id' => $vendedor->id,
            'nombre' => $vendedor->nombre,
            'telefono' => $vendedor->telefono,
            'email' => $vendedor->email,
            'direccion' => $vendedor->direccion,
            'usuario' => $vendedor->usuario,
            'tipo_usuario' => $vendedor->tipo_usuario ?: 'vendedor',
            'fecha_registro' => $regla['fecha_registro'],
            'meses_antiguedad' => $regla['meses_antiguedad'],
            'nivel_embajador' => $regla['nivel'],
            'descuento_credito' => $regla['descuento_credito'],
            'descuento_contado' => $regla['descuento_contado'],
            'descuento_disponible' => [
                'credito' => $regla['descuento_credito'],
                'contado' => $regla['descuento_contado'],
            ],
            'total_ventas_mensual' => $resumenVentas['total_ventas_mensual'],
            'total_ventas_anual' => $resumenVentas['total_ventas_anual'],
            'created_at' => optional($vendedor->created_at)->toISOString(),
            'updated_at' => optional($vendedor->updated_at)->toISOString(),
        ];
    }

    private function resumenVentasVendedor(int $vendedorId): array
    {
        $inicioMes = Carbon::now()->startOfMonth()->toDateString();
        $inicioAnio = Carbon::now()->startOfYear()->toDateString();

        $mensual = (float) VentaCredito::query()
            ->where('vendedor_id', $vendedorId)
            ->whereDate('fecha', '>=', $inicioMes)
            ->sum('monto_total');

        $anual = (float) VentaCredito::query()
            ->where('vendedor_id', $vendedorId)
            ->whereDate('fecha', '>=', $inicioAnio)
            ->sum('monto_total');

        return [
            'total_ventas_mensual' => round($mensual, 2),
            'total_ventas_anual' => round($anual, 2),
        ];
    }

    private function resolverTipoVenta(array $data): string
    {
        if (!empty($data['tipo_venta'])) {
            return (string) $data['tipo_venta'];
        }

        $cantidadPagos = (int) ($data['cantidad_pagos'] ?? 1);
        $fechaVenta = Carbon::parse((string) $data['fecha'])->toDateString();
        $fechaPrimerPago = isset($data['fecha_primer_pago'])
            ? Carbon::parse((string) $data['fecha_primer_pago'])->toDateString()
            : null;

        if ($cantidadPagos === 1 && $fechaPrimerPago !== null && $fechaPrimerPago === $fechaVenta) {
            return 'contado';
        }

        return 'credito';
    }

    private function reglaEmbajador(Vendedor $vendedor, Carbon $fechaBase): array
    {
        $fechaRegistro = $vendedor->created_at ? $vendedor->created_at->copy()->startOfDay() : Carbon::today();
        $meses = max(0, $fechaRegistro->diffInMonths($fechaBase->copy()->startOfDay()));

        if ($meses <= 5) {
            return [
                'nivel' => 'nuevo',
                'meses_antiguedad' => $meses,
                'descuento_credito' => 20.0,
                'descuento_contado' => 25.0,
                'fecha_registro' => $fechaRegistro->toDateString(),
            ];
        }

        if ($meses <= 12) {
            return [
                'nivel' => 'intermedio',
                'meses_antiguedad' => $meses,
                'descuento_credito' => 15.0,
                'descuento_contado' => 20.0,
                'fecha_registro' => $fechaRegistro->toDateString(),
            ];
        }

        return [
            'nivel' => 'consolidado',
            'meses_antiguedad' => $meses,
            'descuento_credito' => 5.0,
            'descuento_contado' => 10.0,
            'fecha_registro' => $fechaRegistro->toDateString(),
        ];
    }

    private function precioConDescuentoEmbajador(float $precioLista, Vendedor $vendedor, string $tipoVenta): float
    {
        $regla = $this->reglaEmbajador($vendedor, Carbon::today());
        $descuento = $tipoVenta === 'contado'
            ? (float) $regla['descuento_contado']
            : (float) $regla['descuento_credito'];

        $factor = max(0, 1 - ($descuento / 100));
        return round($precioLista * $factor, 2);
    }

    private function comisionFijaPorPrecioLista(float $precioLista): float
    {
        if ($precioLista >= 3000) {
            return 500;
        }
        if ($precioLista >= 2800) {
            return 450;
        }
        if ($precioLista >= 2600) {
            return 400;
        }
        if ($precioLista >= 2400) {
            return 350;
        }
        if ($precioLista >= 2200) {
            return 300;
        }
        if ($precioLista >= 2000) {
            return 250;
        }

        return 0;
    }
}
