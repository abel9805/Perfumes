<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ComisionVendedorPerfume;
use App\Models\Cliente;
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
use Illuminate\Support\Facades\Storage;

class AdminEntregasController extends Controller
{
    public function saldoVendedor(Request $request): JsonResponse
    {
        $vendedorId = $request->query('vendedor_id');

        $query = VentaCredito::query()
            ->from('ventas_credito as v')
            ->leftJoin('vendedores as ve', 've.id', '=', 'v.vendedor_id')
            ->whereNotNull('v.vendedor_id')
            ->whereRaw('v.monto_total > v.monto_pagado')
            ->select([
                'v.id as venta_id',
                'v.vendedor_id',
                've.nombre as nombre_vendedor',
                'v.fecha',
                'v.nombre_cliente',
                'v.monto_total',
                'v.monto_pagado',
            ])
            ->orderBy('ve.nombre')
            ->orderByDesc('v.fecha')
            ->orderByDesc('v.id');

        if (!is_null($vendedorId) && $vendedorId !== '') {
            $query->where('v.vendedor_id', (int) $vendedorId);
        }

        $rows = $query->get();

        if ($rows->isEmpty()) {
            return response()->json([]);
        }

        $ventaIds = $rows->pluck('venta_id');
        $pendientes = PagoVentaVendedor::query()
            ->whereIn('venta_id', $ventaIds)
            ->where('estado', 'pendiente_confirmacion')
            ->selectRaw('venta_id, COALESCE(SUM(monto),0) as total')
            ->groupBy('venta_id')
            ->pluck('total', 'venta_id');

        $confirmados = PagoVentaVendedor::query()
            ->whereIn('venta_id', $ventaIds)
            ->where('estado', 'confirmado')
            ->selectRaw('venta_id, COALESCE(SUM(monto),0) as total')
            ->groupBy('venta_id')
            ->pluck('total', 'venta_id');

        $abonosCliente = PagoVenta::query()
            ->whereIn('venta_id', $ventaIds)
            ->where(function ($q) {
                $q->whereNull('notas')
                    ->orWhere('notas', 'not like', 'Pago confirmado%');
            })
            ->selectRaw('venta_id, COALESCE(SUM(monto),0) as total')
            ->groupBy('venta_id')
            ->pluck('total', 'venta_id');

        $result = $rows->map(function ($row) use ($pendientes, $confirmados, $abonosCliente) {
            $saldo = max(0, (float) $row->monto_total - (float) $row->monto_pagado);
            $pendienteConfirmar = (float) ($pendientes[$row->venta_id] ?? 0);
            $confirmadoVendedor = (float) ($confirmados[$row->venta_id] ?? 0);
            $abonosVentas = (float) ($abonosCliente[$row->venta_id] ?? 0);

            $calculo = $this->calcularReglaPagoVendedorAdmin(
                (float) $row->monto_total,
                (float) $row->monto_pagado,
                $row->fecha,
                $row->fecha_primer_pago,
                null,
                $pendienteConfirmar,
                $confirmadoVendedor,
                $abonosVentas
            );

            return [
                'venta_id' => (int) $row->venta_id,
                'vendedor_id' => (int) $row->vendedor_id,
                'nombre_vendedor' => $row->nombre_vendedor,
                'fecha' => $row->fecha,
                'fecha_primer_pago' => $calculo['fecha_primer_pago'],
                'nombre_cliente' => $row->nombre_cliente,
                'monto_total' => (float) $row->monto_total,
                'monto_pagado' => (float) $row->monto_pagado,
                'saldo_pendiente' => $saldo,
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

        return response()->json($result);
    }

    private function calcularReglaPagoVendedorAdmin(
        float $montoTotal,
        float $montoPagado,
        string $fechaVenta,
        ?string $fechaPrimerPago,
        ?int $cantidadPagos,
        float $pendienteConfirmar,
        float $confirmadoVendedor,
        float $abonosCliente
    ): array {
        $montoTotal = max(0, round($montoTotal, 2));
        $montoPagado = max(0, round($montoPagado, 2));
        $saldoActual = max(0, round($montoTotal - $montoPagado, 2));

        $cantidadPagos = max(1, (int) ($cantidadPagos ?? 1));
        $fechaPrimerPagoCarbon = $fechaPrimerPago
            ? Carbon::parse($fechaPrimerPago)->startOfDay()
            : Carbon::parse($this->nextPaymentCutoffOnOrAfterAdmin($fechaVenta))->startOfDay();

        $cuotasHabilitadas = $this->cuotasHabilitadasHastaHoyAdmin($fechaPrimerPagoCarbon, $cantidadPagos);
        $montoPagoCorrespondiente = round(min($montoTotal, ($montoTotal / $cantidadPagos) * $cuotasHabilitadas), 2);
        $montoAbonosVentas = round(min($montoTotal, max(0, $abonosCliente)), 2);
        $montoProgramadoRegla = round(min($montoTotal, $montoPagoCorrespondiente + $montoAbonosVentas), 2);

        $montoProgramadoNeto = max(0, round($montoProgramadoRegla - $confirmadoVendedor - $pendienteConfirmar, 2));
        $montoDisponibleSaldo = max(0, round($saldoActual - $pendienteConfirmar, 2));
        $montoDisponiblePagar = round(min($montoDisponibleSaldo, $montoProgramadoNeto), 2);

        return [
            'fecha_primer_pago' => $fechaPrimerPagoCarbon->toDateString(),
            'cantidad_pagos' => $cantidadPagos,
            'cuotas_habilitadas_hoy' => $cuotasHabilitadas,
            'monto_pago_correspondiente' => $montoPagoCorrespondiente,
            'monto_abonos_ventas' => $montoAbonosVentas,
            'monto_programado_regla' => $montoProgramadoRegla,
            'monto_disponible_pagar' => $montoDisponiblePagar,
        ];
    }

    private function cuotasHabilitadasHastaHoyAdmin(Carbon $fechaPrimerPago, int $cantidadPagos): int
    {
        $hoy = Carbon::today();
        $cursor = $fechaPrimerPago->copy()->startOfDay();
        $habilitadas = 0;

        for ($i = 0; $i < $cantidadPagos; $i++) {
            if ($cursor->lte($hoy)) {
                $habilitadas++;
            }

            $cursor = $this->nextQuincenalCutoffAdmin($cursor);
        }

        return $habilitadas;
    }

    private function nextQuincenalCutoffAdmin(Carbon $fecha): Carbon
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

    private function nextPaymentCutoffOnOrAfterAdmin(string $date): string
    {
        $d = Carbon::parse($date)->startOfDay();
        $lastDay = $d->copy()->endOfMonth()->day;

        if ($d->day <= 15) {
            return $d->copy()->day(15)->toDateString();
        }

        return $d->copy()->day($lastDay)->toDateString();
    }

    public function pagosVendedorPorConfirmar(Request $request): JsonResponse
    {
        $vendedorId = $request->query('vendedor_id');

        $query = PagoVentaVendedor::query()
            ->from('pagos_venta_vendedor as p')
            ->join('ventas_credito as v', 'v.id', '=', 'p.venta_id')
            ->join('vendedores as ve', 've.id', '=', 'v.vendedor_id')
            ->where('p.estado', 'pendiente_confirmacion')
            ->select([
                'p.id',
                'p.venta_id',
                'p.monto',
                'p.fecha',
                'p.nota',
                'v.vendedor_id',
                've.nombre as nombre_vendedor',
                'v.nombre_cliente',
                'v.fecha as fecha_venta',
                'v.monto_total',
                'v.monto_pagado',
            ])
            ->orderByDesc('p.fecha')
            ->orderByDesc('p.id');

        if (!is_null($vendedorId) && $vendedorId !== '') {
            $query->where('v.vendedor_id', (int) $vendedorId);
        }

        $rows = $query->get()->map(function ($row) {
            $saldoActual = max(0, (float) $row->monto_total - (float) $row->monto_pagado);
            return [
                'id' => (int) $row->id,
                'venta_id' => (int) $row->venta_id,
                'monto' => (float) $row->monto,
                'fecha' => $row->fecha,
                'nota' => $row->nota,
                'vendedor_id' => (int) $row->vendedor_id,
                'nombre_vendedor' => $row->nombre_vendedor,
                'nombre_cliente' => $row->nombre_cliente,
                'fecha_venta' => $row->fecha_venta,
                'monto_total' => (float) $row->monto_total,
                'monto_pagado' => (float) $row->monto_pagado,
                'saldo_pendiente' => $saldoActual,
            ];
        })->values();

        return response()->json($rows);
    }

    public function confirmarPagoVendedor(int $pagoId): JsonResponse
    {
        $result = DB::transaction(function () use ($pagoId) {
            $pago = PagoVentaVendedor::query()->lockForUpdate()->find($pagoId);
            if (!$pago) {
                return [
                    'error' => response()->json(['message' => 'Pago no encontrado'], 404),
                ];
            }

            if ($pago->estado === 'confirmado') {
                return [
                    'ok' => [
                        'message' => 'Pago ya estaba confirmado',
                        'pago_id' => $pago->id,
                    ],
                ];
            }

            $venta = VentaCredito::query()->lockForUpdate()->find($pago->venta_id);
            if (!$venta) {
                return [
                    'error' => response()->json(['message' => 'Venta asociada no encontrada'], 404),
                ];
            }

            $saldoActual = max(0, (float) $venta->monto_total - (float) $venta->monto_pagado);
            if ($saldoActual <= 0) {
                $pago->estado = 'rechazado';
                $pago->save();

                return [
                    'error' => response()->json([
                        'message' => 'La venta ya no tiene saldo pendiente',
                        'pago_id' => $pago->id,
                    ], 422),
                ];
            }

            $montoAplicar = min((float) $pago->monto, $saldoActual);

            $pagoAdmin = PagoVenta::create([
                'venta_id' => $venta->id,
                'monto' => $montoAplicar,
                'fecha' => $pago->fecha ?: Carbon::today()->toDateString(),
                'notas' => trim((string) ($pago->nota ?? '')) === ''
                    ? 'Pago confirmado desde saldo por pagar vendedor'
                    : 'Pago confirmado vendedor: ' . $pago->nota,
            ]);

            $venta->monto_pagado = (float) $venta->monto_pagado + $montoAplicar;
            $venta->saldo_pendiente = max(0, (float) $venta->monto_total - (float) $venta->monto_pagado);
            $venta->estado = $venta->saldo_pendiente <= 0 ? 'pagado' : 'pendiente';
            $venta->save();

            $pago->estado = 'confirmado';
            $pago->fecha_confirmacion = Carbon::now();
            $pago->save();

            return [
                'ok' => [
                    'message' => 'Pago confirmado y aplicado a la venta',
                    'pago_id' => $pago->id,
                    'venta_id' => $venta->id,
                    'pago_admin_id' => $pagoAdmin->id,
                    'monto_aplicado' => $montoAplicar,
                    'saldo_pendiente' => (float) $venta->saldo_pendiente,
                ],
            ];
        });

        if (isset($result['error'])) {
            return $result['error'];
        }

        return response()->json($result['ok']);
    }

    public function resumen(): JsonResponse
    {
        $totalPerfumes = Perfume::count();
        $totalVendedores = Vendedor::count();
        $totalClientes = Cliente::count();
        $ventasPendientes = VentaCredito::where('estado', '!=', 'pagado')->count();
        $saldoPendiente = (float) VentaCredito::selectRaw('COALESCE(SUM(monto_total - monto_pagado), 0) as s')->value('s');
        $entregasPendientes = EntregaVendedor::where('tipo', 'entrega')
            ->whereIn('estado', ['solicitado', 'pendiente', 'pendiente_confirmacion'])
            ->count();

        return response()->json([
            'totalPerfumes' => $totalPerfumes,
            'totalVendedores' => $totalVendedores,
            'totalClientes' => $totalClientes,
            'ventasPendientes' => $ventasPendientes,
            'saldoPendiente' => $saldoPendiente,
            'entregasPendientes' => $entregasPendientes,
        ]);
    }

    public function ventasPorVendedor(): JsonResponse
    {
        $rows = DB::table('ventas_credito as v')
            ->leftJoin('vendedores as ve', 'v.vendedor_id', '=', 've.id')
            ->selectRaw("COALESCE(ve.id, 0) as vendedor_id")
            ->selectRaw("COALESCE(ve.nombre, 'Sin vendedor') as nombre_vendedor")
            ->selectRaw('COUNT(v.id) as total_ventas')
            ->selectRaw('COALESCE(SUM(v.monto_total), 0) as monto_total')
            ->selectRaw('COALESCE(SUM(v.monto_pagado), 0) as monto_pagado')
            ->selectRaw('COALESCE(SUM(v.monto_total - v.monto_pagado), 0) as saldo_pendiente')
            ->groupBy('ve.id', 've.nombre')
            ->orderByDesc('monto_total')
            ->orderBy('nombre_vendedor')
            ->get();

        return response()->json($rows);
    }

    public function comisionesPerfumesVendidos(): JsonResponse
    {
        $rows = DB::table('detalles_venta as d')
            ->join('ventas_credito as v', 'v.id', '=', 'd.venta_id')
            ->join('vendedores as ve', 've.id', '=', 'v.vendedor_id')
            ->join('perfumes as p', 'p.id', '=', 'd.perfume_id')
            ->leftJoin('comisiones_vendedor_perfume as cp', function ($join) {
                $join->on('cp.vendedor_id', '=', 'v.vendedor_id')
                    ->on('cp.perfume_id', '=', 'd.perfume_id');
            })
            ->whereNotNull('v.vendedor_id')
            ->groupBy(
                'v.vendedor_id',
                've.nombre',
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
            ->orderBy('ve.nombre')
            ->orderBy('p.nombre')
            ->get([
                DB::raw('v.vendedor_id as vendedor_id'),
                DB::raw('ve.nombre as nombre_vendedor'),
                DB::raw('d.perfume_id as perfume_id'),
                DB::raw('p.nombre as nombre_perfume'),
                DB::raw('p.marca as marca_perfume'),
                DB::raw('p.precio_venta as precio_lista'),
                DB::raw('SUM(d.cantidad) as cantidad_vendida'),
                DB::raw('SUM(d.cantidad * d.precio_unitario) as monto_vendido'),
                DB::raw('SUM(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) <= CURDATE() THEN d.cantidad ELSE 0 END) as cantidad_habilitada_comision'),
                DB::raw('SUM(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) <= CURDATE() THEN (d.cantidad * d.precio_unitario) ELSE 0 END) as monto_habilitado_comision'),
                DB::raw('MIN(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) > CURDATE() THEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) ELSE NULL END) as proxima_fecha_comision'),
                DB::raw('COALESCE(cp.monto_por_confirmar, 0) as comision_por_confirmar'),
                DB::raw('COALESCE(cp.monto_cobrado, 0) as comision_cobrada'),
                DB::raw('cp.fecha_pago_admin as fecha_pago_admin'),
                DB::raw('cp.fecha_cobro_vendedor as fecha_cobro_vendedor'),
            ]);

        return response()->json($rows->map(function ($row) {
            $precioLista = (float) ($row->precio_lista ?? 0);
            $comisionValor = $this->comisionFijaPorPrecioLista($precioLista);
            $cantidadHabilitada = (float) ($row->cantidad_habilitada_comision ?? 0);
            $comisionHabilitada = round($cantidadHabilitada * $comisionValor, 2);
            $porConfirmar = (float) ($row->comision_por_confirmar ?? 0);
            $cobrada = (float) ($row->comision_cobrada ?? 0);
            $comisionDisponible = max(0, round($comisionHabilitada - $porConfirmar - $cobrada, 2));

            $estadoPago = 'por_pagar';
            if ($porConfirmar > 0) {
                $estadoPago = 'por_confirmar';
            } elseif ($comisionDisponible <= 0 && $cobrada > 0) {
                $estadoPago = 'cobrado';
            }

            return [
                'vendedor_id' => (int) $row->vendedor_id,
                'nombre_vendedor' => $row->nombre_vendedor,
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
                'comision_por_confirmar' => $porConfirmar,
                'comision_cobrada' => $cobrada,
                'comision_disponible' => $comisionDisponible,
                'fecha_pago_admin' => $row->fecha_pago_admin,
                'fecha_cobro_vendedor' => $row->fecha_cobro_vendedor,
                'estado_pago' => $estadoPago,
            ];
        })->values());
    }

    public function storeComisionPerfume(Request $request): JsonResponse
    {
        $data = $request->validate([
            'vendedor_id' => ['required', 'integer', 'exists:vendedores,id'],
            'perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
        ]);

        $tieneVentas = DB::table('detalles_venta as d')
            ->join('ventas_credito as v', 'v.id', '=', 'd.venta_id')
            ->where('v.vendedor_id', (int) $data['vendedor_id'])
            ->where('d.perfume_id', (int) $data['perfume_id'])
            ->exists();

        if (!$tieneVentas) {
            return response()->json([
                'message' => 'Ese perfume no tiene ventas para el vendedor seleccionado',
            ], 422);
        }

        $perfume = Perfume::find((int) $data['perfume_id']);
        if (!$perfume) {
            return response()->json(['message' => 'Perfume no encontrado'], 404);
        }

        $valor = $this->comisionFijaPorPrecioLista((float) $perfume->precio_venta);

        $comision = ComisionVendedorPerfume::query()->updateOrCreate(
            [
                'vendedor_id' => (int) $data['vendedor_id'],
                'perfume_id' => (int) $data['perfume_id'],
            ],
            [
                'comision_tipo' => 'rango_precio',
                'comision_valor' => round($valor, 2),
            ]
        );

        return response()->json([
            'message' => 'Comisión automática asignada por precio de lista',
            'item' => $comision,
        ]);
    }

    public function pagarComisionPerfume(Request $request): JsonResponse
    {
        $data = $request->validate([
            'vendedor_id' => ['required', 'integer', 'exists:vendedores,id'],
            'perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
            'monto' => ['required', 'numeric', 'min:0.01'],
        ]);

        $perfume = Perfume::find((int) $data['perfume_id']);
        if (!$perfume) {
            return response()->json(['message' => 'Perfume no encontrado'], 404);
        }

        $valorComision = $this->comisionFijaPorPrecioLista((float) $perfume->precio_venta);
        $comision = ComisionVendedorPerfume::query()->firstOrCreate(
            [
                'vendedor_id' => (int) $data['vendedor_id'],
                'perfume_id' => (int) $data['perfume_id'],
            ],
            [
                'comision_tipo' => 'rango_precio',
                'comision_valor' => round($valorComision, 2),
            ]
        );

        $comision->comision_tipo = 'rango_precio';
        $comision->comision_valor = round($valorComision, 2);

        $habilitada = $this->calcularComisionHabilitada(
            (int) $data['vendedor_id'],
            (int) $data['perfume_id']
        );
        $porConfirmar = (float) ($comision->monto_por_confirmar ?? 0);
        $cobrada = (float) ($comision->monto_cobrado ?? 0);
        $disponible = max(0, $habilitada - $porConfirmar - $cobrada);

        $monto = round((float) $data['monto'], 2);
        if ($monto > $disponible) {
            return response()->json([
                'message' => 'El monto excede la comisión disponible para pagar',
                'disponible' => round($disponible, 2),
            ], 422);
        }

        $comision->estado_pago = 'por_confirmar';
        $comision->fecha_pago_admin = Carbon::now();
        $comision->monto_por_confirmar = round($porConfirmar + $monto, 2);
        $comision->save();

        return response()->json([
            'message' => 'Comisión marcada como pendiente por confirmar',
            'item' => $comision,
        ]);
    }

    private function calcularComisionHabilitada(int $vendedorId, int $perfumeId): float
    {
        $perfume = Perfume::find($perfumeId);
        if (!$perfume) {
            return 0;
        }

        $row = DB::table('detalles_venta as d')
            ->join('ventas_credito as v', 'v.id', '=', 'd.venta_id')
            ->where('v.vendedor_id', $vendedorId)
            ->where('d.perfume_id', $perfumeId)
            ->selectRaw('COALESCE(SUM(CASE WHEN COALESCE(v.fecha_primer_pago, DATE_ADD(v.fecha, INTERVAL 15 DAY)) <= CURDATE() THEN d.cantidad ELSE 0 END), 0) as cantidad_habilitada')
            ->first();

        $cantidadHabilitada = (float) ($row->cantidad_habilitada ?? 0);
        $valorComision = $this->comisionFijaPorPrecioLista((float) $perfume->precio_venta);

        return round($cantidadHabilitada * $valorComision, 2);
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

    public function perfumes(): JsonResponse
    {
        $rows = Perfume::query()
            ->orderBy('nombre')
            ->get(['id', 'nombre', 'marca', 'mililitros', 'concentracion', 'descripcion', 'precio_costo', 'precio_venta', 'stock', 'imagen']);

        return response()->json($rows->map(fn(Perfume $p) => $this->perfumePayload($p))->values());
    }

    public function storePerfume(Request $request): JsonResponse
    {
        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'marca' => ['required', 'string'],
            'mililitros' => ['nullable', 'integer', 'min:1'],
            'concentracion' => ['nullable', 'string', 'max:60'],
            'descripcion' => ['nullable', 'string'],
            'precio_costo' => ['required', 'numeric', 'min:0'],
            'precio_venta' => ['required', 'numeric', 'min:0'],
            'stock' => ['nullable', 'integer', 'min:0'],
            'imagen' => ['nullable', 'image', 'max:4096'],
        ]);

        $perfumeData = [
            'nombre' => $data['nombre'],
            'marca' => $data['marca'],
            'mililitros' => $data['mililitros'] ?? null,
            'concentracion' => $data['concentracion'] ?? null,
            'descripcion' => $data['descripcion'] ?? null,
            'precio_costo' => $data['precio_costo'],
            'precio_venta' => $data['precio_venta'],
            'stock' => $data['stock'] ?? 0,
        ];

        if ($request->hasFile('imagen')) {
            $perfumeData['imagen'] = $request->file('imagen')->store('perfumes', 'public');
        }

        $perfume = Perfume::create($perfumeData);

        return response()->json($this->perfumePayload($perfume), 201);
    }

    public function updatePerfume(Request $request, int $id): JsonResponse
    {
        $perfume = Perfume::find($id);
        if (!$perfume) {
            return response()->json(['message' => 'Perfume no encontrado'], 404);
        }

        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'marca' => ['required', 'string'],
            'mililitros' => ['nullable', 'integer', 'min:1'],
            'concentracion' => ['nullable', 'string', 'max:60'],
            'descripcion' => ['nullable', 'string'],
            'precio_costo' => ['required', 'numeric', 'min:0'],
            'precio_venta' => ['required', 'numeric', 'min:0'],
            'stock' => ['required', 'integer', 'min:0'],
            'imagen' => ['nullable', 'image', 'max:4096'],
        ]);

        if ($request->hasFile('imagen')) {
            if (!empty($perfume->imagen)) {
                Storage::disk('public')->delete($perfume->imagen);
            }
            $data['imagen'] = $request->file('imagen')->store('perfumes', 'public');
        }

        $perfume->update($data);

        return response()->json($this->perfumePayload($perfume));
    }

    public function destroyPerfume(int $id): JsonResponse
    {
        $perfume = Perfume::find($id);
        if (!$perfume) {
            return response()->json(['message' => 'Perfume no encontrado'], 404);
        }

        $tieneEntregas = EntregaVendedor::where('perfume_id', $id)->exists();
        $tieneDetalles = DetalleVenta::where('perfume_id', $id)->exists();

        if ($tieneEntregas || $tieneDetalles) {
            return response()->json([
                'message' => 'No se puede eliminar el perfume porque tiene entregas o ventas asociadas',
            ], 409);
        }

        if (!empty($perfume->imagen)) {
            Storage::disk('public')->delete($perfume->imagen);
        }

        $perfume->delete();

        return response()->json(['message' => 'Perfume eliminado correctamente']);
    }

    private function perfumePayload(Perfume $perfume): array
    {
        return [
            'id' => $perfume->id,
            'nombre' => $perfume->nombre,
            'marca' => $perfume->marca,
            'mililitros' => $perfume->mililitros,
            'concentracion' => $perfume->concentracion,
            'descripcion' => $perfume->descripcion,
            'precio_costo' => $perfume->precio_costo,
            'precio_venta' => $perfume->precio_venta,
            'stock' => $perfume->stock,
            'imagen' => $perfume->imagen,
            'imagen_url' => $perfume->imagen ? Storage::disk('public')->url($perfume->imagen) : null,
        ];
    }

    public function vendedores(): JsonResponse
    {
        $rows = Vendedor::query()
            ->orderBy('nombre')
            ->get();

        return response()->json(
            $rows->map(fn (Vendedor $v) => $this->vendedorPayload($v))->values()
        );
    }

    public function storeVendedor(Request $request): JsonResponse
    {
        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'telefono' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'direccion' => ['nullable', 'string'],
            'usuario' => ['required', 'string', 'unique:vendedores,usuario'],
            'password' => ['required', 'string'],
            'tipo_usuario' => ['nullable', 'string', 'in:colega,vendedor'],
            'initial_entregas' => ['nullable', 'array'],
            'initial_entregas.*.perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
            'initial_entregas.*.cantidad' => ['required', 'integer', 'min:1'],
            'initial_entregas.*.precio_unitario' => ['required', 'numeric', 'min:0'],
            'initial_entregas.*.fecha' => ['required', 'date'],
        ]);

        $vendedor = DB::transaction(function () use ($data) {
            $vendedor = Vendedor::create([
                'nombre' => $data['nombre'],
                'telefono' => $data['telefono'] ?? null,
                'email' => $data['email'] ?? null,
                'direccion' => $data['direccion'] ?? null,
                'usuario' => $data['usuario'],
                'password' => $data['password'],
                'tipo_usuario' => $data['tipo_usuario'] ?? 'vendedor',
            ]);

            foreach (($data['initial_entregas'] ?? []) as $entrega) {
                EntregaVendedor::create([
                    'vendedor_id' => $vendedor->id,
                    'perfume_id' => (int) $entrega['perfume_id'],
                    'tipo' => 'inicial',
                    'cantidad' => (int) $entrega['cantidad'],
                    'precio_unitario' => (float) $entrega['precio_unitario'],
                    'fecha' => $entrega['fecha'],
                    'estado' => 'pendiente_confirmacion',
                ]);
            }

            return $vendedor;
        });

        return response()->json($this->vendedorPayload($vendedor), 201);
    }

    public function updateVendedor(Request $request, int $id): JsonResponse
    {
        $vendedor = Vendedor::find($id);
        if (!$vendedor) {
            return response()->json(['message' => 'Vendedor no encontrado'], 404);
        }

        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'telefono' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'direccion' => ['nullable', 'string'],
            'usuario' => ['required', 'string', 'unique:vendedores,usuario,' . $id],
            'password' => ['nullable', 'string'],
            'tipo_usuario' => ['nullable', 'string', 'in:colega,vendedor'],
        ]);

        if (empty($data['password'])) {
            unset($data['password']);
        }

        if (empty($data['tipo_usuario'])) {
            unset($data['tipo_usuario']);
        }

        $vendedor->update($data);

        return response()->json($this->vendedorPayload($vendedor));
    }

    public function destroyVendedor(Request $request, int $id): JsonResponse
    {
        $vendedor = Vendedor::find($id);
        if (!$vendedor) {
            return response()->json(['message' => 'Vendedor no encontrado'], 404);
        }

        $force = filter_var($request->query('force', false), FILTER_VALIDATE_BOOL);

        $tieneEntregas = EntregaVendedor::where('vendedor_id', $id)->exists();
        $tieneClientes = Cliente::where('vendedor_id', $id)->exists();
        $tieneVentas = VentaCredito::where('vendedor_id', $id)->exists();

        if (!$force && ($tieneEntregas || $tieneClientes || $tieneVentas)) {
            return response()->json([
                'message' => 'No se puede eliminar el vendedor porque tiene entregas, clientes o ventas asociadas',
            ], 409);
        }

        $vendedor->delete();

        return response()->json([
            'message' => 'Vendedor eliminado correctamente',
        ]);
    }

    public function clientes(Request $request): JsonResponse
    {
        $query = Cliente::query()->whereNull('vendedor_id');

        $rows = $query->orderBy('nombre')->get();

        return response()->json($rows);
    }

    public function storeCliente(Request $request): JsonResponse
    {
        $data = $request->validate([
            'nombre' => ['required', 'string'],
            'telefono' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'direccion' => ['nullable', 'string'],
        ]);

        $cliente = Cliente::create([
            'vendedor_id' => null,
            'nombre' => $data['nombre'],
            'telefono' => $data['telefono'] ?? null,
            'email' => $data['email'] ?? null,
            'direccion' => $data['direccion'] ?? null,
        ]);

        return response()->json($cliente, 201);
    }

    public function updateCliente(Request $request, int $id): JsonResponse
    {
        $cliente = Cliente::query()->whereNull('vendedor_id')->find($id);
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

    public function destroyCliente(int $id): JsonResponse
    {
        $cliente = Cliente::query()->whereNull('vendedor_id')->find($id);
        if (!$cliente) {
            return response()->json(['message' => 'Cliente no encontrado'], 404);
        }

        if ($this->clienteTieneVentasPendientes((int) $cliente->id)) {
            return response()->json([
                'message' => 'No se puede eliminar el cliente porque tiene ventas a credito pendientes',
            ], 409);
        }

        $cliente->delete();

        return response()->json(['message' => 'Cliente eliminado correctamente']);
    }

    private function clienteTieneVentasPendientes(int $clienteId): bool
    {
        return VentaCredito::query()
            ->where('cliente_id', $clienteId)
            ->where('estado', '!=', 'pagado')
            ->exists();
    }

    public function entregas(Request $request): JsonResponse
    {
        $tipo = $request->query('tipo', 'todos');
        $query = DB::table('entregas_vendedor as e')
            ->join('vendedores as v', 'e.vendedor_id', '=', 'v.id')
            ->join('perfumes as p', 'e.perfume_id', '=', 'p.id')
            ->select([
                'e.id',
                'e.tipo',
                'e.vendedor_id',
                'e.perfume_id',
                'e.cantidad',
                'e.precio_unitario',
                'e.fecha',
                'e.estado',
                DB::raw('v.nombre as nombre_vendedor'),
                DB::raw('p.nombre as nombre_perfume'),
            ]);

        $vendedorId = $request->query('vendedor_id');
        if ($vendedorId !== null) {
            $query->where('e.vendedor_id', (int) $vendedorId);
        }

        if (is_string($tipo) && $tipo !== 'todos') {
            $query->where('e.tipo', $tipo);
        }

        $estado = $request->query('estado');
        if (is_string($estado) && $estado !== '') {
            $query->where('e.estado', $estado);
        }

        return response()->json($query->orderByDesc('e.fecha')->orderByDesc('e.id')->get());
    }

    public function pedidos(Request $request): JsonResponse
    {
        $request->query->set('tipo', 'pedido');

        return $this->entregas($request);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'vendedor_id' => ['required', 'integer', 'exists:vendedores,id'],
            'perfume_id' => ['required', 'integer', 'exists:perfumes,id'],
            'tipo' => ['nullable', 'string', 'in:entrega,inicial,pedido'],
            'cantidad' => ['required', 'integer', 'min:1'],
            'precio_unitario' => ['required', 'numeric', 'min:0'],
            'fecha' => ['required', 'date'],
            'estado' => ['nullable', 'string'],
        ]);

        $entrega = EntregaVendedor::create([
            'vendedor_id' => $data['vendedor_id'],
            'perfume_id' => $data['perfume_id'],
            'tipo' => $data['tipo'] ?? 'entrega',
            'cantidad' => $data['cantidad'],
            'precio_unitario' => $data['precio_unitario'],
            'fecha' => $data['fecha'],
            'estado' => $data['estado'] ?? 'pendiente_confirmacion',
        ]);

        return response()->json($entrega, 201);
    }

    public function show(int $id): JsonResponse
    {
        $entrega = EntregaVendedor::find($id);
        if (!$entrega) {
            return response()->json(['message' => 'Entrega no encontrada'], 404);
        }
        return response()->json($entrega);
    }

    public function updateEntregaEstado(Request $request, int $id): JsonResponse
    {
        $entrega = EntregaVendedor::find($id);
        if (!$entrega) {
            return response()->json(['message' => 'Entrega no encontrada'], 404);
        }

        $data = $request->validate([
            'estado' => ['required', 'string'],
            'cantidad' => ['nullable', 'integer', 'min:1'],
        ]);

        if (in_array($data['estado'], ['confirmado', 'pagado'], true)) {
            return response()->json([
                'message' => 'El admin no puede confirmar ni marcar pagada una entrega. Esa accion corresponde al vendedor.',
            ], 403);
        }

        $entrega->estado = $data['estado'];
        if (isset($data['cantidad'])) {
            $entrega->cantidad = (int) $data['cantidad'];
        }
        $entrega->save();

        return response()->json($entrega);
    }

    public function destroyEntrega(int $id): JsonResponse
    {
        $entrega = EntregaVendedor::find($id);
        if (!$entrega) {
            return response()->json(['message' => 'Entrega no encontrada'], 404);
        }

        if (in_array($entrega->estado, ['confirmado', 'pagado'], true)) {
            return response()->json([
                'message' => 'No se puede eliminar una entrega confirmada o pagada',
            ], 409);
        }

        $entrega->delete();

        return response()->json(['message' => 'Entrega eliminada correctamente']);
    }

    public function ventas(Request $request): JsonResponse
    {
        $query = DB::table('ventas_credito as v')
            ->join('clientes as c', 'v.cliente_id', '=', 'c.id')
            ->leftJoin('vendedores as ve', 'v.vendedor_id', '=', 've.id')
            ->select([
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
                DB::raw('ve.nombre as nombre_vendedor'),
            ]);

        $vendedorId = $request->query('vendedor_id');
        if ($vendedorId !== null) {
            $query->where('v.vendedor_id', (int) $vendedorId);
        }

        $clienteId = $request->query('cliente_id');
        if ($clienteId !== null) {
            $query->where('v.cliente_id', (int) $clienteId);
        }
        return response()->json($query->orderByDesc('v.fecha')->orderByDesc('v.id')->get());
    }

    public function storeVenta(Request $request): JsonResponse
    {
        $data = $request->validate([
            'cliente_id' => ['required', 'integer', 'exists:clientes,id'],
            'vendedor_id' => ['nullable', 'integer', 'exists:vendedores,id'],
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

        $cliente = Cliente::find((int) $data['cliente_id']);
        if (!$cliente) {
            return response()->json(['message' => 'Cliente no encontrado'], 404);
        }

        $vendedorId = isset($data['vendedor_id']) ? (int) $data['vendedor_id'] : null;
        if ($vendedorId !== null && (int) ($cliente->vendedor_id ?? 0) !== $vendedorId) {
            return response()->json(['message' => 'El cliente no pertenece al vendedor seleccionado'], 422);
        }

        if ($vendedorId !== null) {
            foreach ($data['items'] as $item) {
                $disponible = $this->stockDisponiblePerfume($vendedorId, (int) $item['perfume_id']);
                if ((int) $item['cantidad'] > $disponible) {
                    return response()->json([
                        'message' => 'Stock insuficiente para uno de los perfumes',
                        'perfume_id' => (int) $item['perfume_id'],
                        'stock_disponible' => $disponible,
                    ], 422);
                }
            }
        }

        $vendedor = $vendedorId !== null ? Vendedor::find($vendedorId) : null;
        $tipoVenta = $this->resolverTipoVenta($data);

        $venta = DB::transaction(function () use ($data, $vendedorId, $vendedor, $tipoVenta) {
            $usarReglaEmbajador = $vendedorId !== null && $vendedor !== null;
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

                $precioUnitario = $usarReglaEmbajador
                    ? $this->precioConDescuentoEmbajador((float) $perfume->precio_venta, $vendedor, $tipoVenta)
                    : round((float) $item['precio_unitario'], 2);

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
                'vendedor_id' => $vendedorId,
                'fecha' => $data['fecha'],
                'fecha_primer_pago' => $data['fecha_primer_pago']
                    ?? Carbon::parse($data['fecha'])->addDays(15)->toDateString(),
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

                if ($vendedorId === null) {
                    Perfume::where('id', (int) $item['perfume_id'])
                        ->decrement('stock', (int) $item['cantidad']);
                }
            }

            return $venta;
        });

        return response()->json($venta, 201);
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

    public function detallesVenta(int $id): JsonResponse
    {
        $venta = VentaCredito::find($id);
        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada'], 404);
        }

        $rows = DB::table('detalles_venta as d')
            ->join('perfumes as p', 'd.perfume_id', '=', 'p.id')
            ->where('d.venta_id', $id)
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

    public function pagosVenta(int $id): JsonResponse
    {
        $venta = VentaCredito::find($id);
        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada'], 404);
        }

        $rows = PagoVenta::query()
            ->where('venta_id', $id)
            ->orderByDesc('fecha')
            ->orderByDesc('id')
            ->get();

        return response()->json($rows);
    }

    public function storePagoVenta(Request $request, int $id): JsonResponse
    {
        $venta = VentaCredito::find($id);
        if (!$venta) {
            return response()->json(['message' => 'Venta no encontrada'], 404);
        }

        if ($venta->vendedor_id !== null) {
            return response()->json([
                'message' => 'El admin no puede registrar pagos de ventas de vendedores',
            ], 403);
        }

        $data = $request->validate([
            'monto' => ['required', 'numeric', 'min:0.01'],
            'fecha' => ['required', 'date'],
            'notas' => ['nullable', 'string'],
            'comision_tipo' => ['nullable', 'string', 'in:monto,porcentaje'],
            'comision_valor' => ['nullable', 'numeric', 'min:0.01', 'required_with:comision_tipo'],
        ]);

        if (($data['comision_tipo'] ?? null) === 'porcentaje' && (float) ($data['comision_valor'] ?? 0) > 100) {
            return response()->json(['message' => 'El porcentaje de comisión no puede superar 100%'], 422);
        }

        if (!empty($data['comision_tipo']) && $venta->vendedor_id === null) {
            return response()->json(['message' => 'La comisión solo aplica a ventas asociadas a un vendedor'], 422);
        }

        $saldoPendiente = ((float) $venta->monto_total) - ((float) $venta->monto_pagado);
        if (((float) $data['monto']) > $saldoPendiente) {
            return response()->json(['message' => 'El monto excede el saldo pendiente'], 422);
        }

        $pago = DB::transaction(function () use ($venta, $data) {
            $tipoComision = $data['comision_tipo'] ?? null;
            $valorComision = (float) ($data['comision_valor'] ?? 0);
            $comisionTotal = 0.0;

            if (!empty($tipoComision) && $venta->vendedor_id !== null) {
                if ($tipoComision === 'monto') {
                    $unidades = (int) DetalleVenta::query()
                        ->where('venta_id', $venta->id)
                        ->sum('cantidad');
                    $comisionTotal = $valorComision * max(0, $unidades);
                } elseif ($tipoComision === 'porcentaje') {
                    $comisionTotal = ((float) $venta->monto_total) * ($valorComision / 100);
                }
            }

            $pago = PagoVenta::create([
                'venta_id' => $venta->id,
                'monto' => (float) $data['monto'],
                'fecha' => $data['fecha'],
                'notas' => $data['notas'] ?? null,
                'comision_tipo' => $tipoComision,
                'comision_valor' => round($valorComision, 2),
                'comision_total' => round($comisionTotal, 2),
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

    private function stockDisponiblePerfume(int $vendedorId, int $perfumeId): int
    {
        $row = DB::table('entregas_vendedor as e')
            ->join('perfumes as p', 'p.id', '=', 'e.perfume_id')
            ->where('e.vendedor_id', $vendedorId)
            ->whereIn('e.estado', ['confirmado', 'pagado'])
            ->where('p.id', $perfumeId)
            ->groupBy('p.id')
            ->selectRaw('COALESCE(SUM(e.cantidad), 0) - COALESCE((SELECT SUM(dv.cantidad) FROM detalles_venta dv JOIN ventas_credito vv ON vv.id = dv.venta_id WHERE vv.vendedor_id = ? AND dv.perfume_id = p.id), 0) as cantidad', [$vendedorId])
            ->first();

        return max(0, (int) ($row->cantidad ?? 0));
    }
}
