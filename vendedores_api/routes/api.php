<?php

use App\Http\Controllers\Api\VendedorAppController;
use App\Http\Controllers\Api\AdminEntregasController;
use Illuminate\Support\Facades\Route;

Route::prefix('vendedor')->group(function () {
    Route::post('/login', [VendedorAppController::class, 'login']);
    Route::get('/{id}/pendientes', [VendedorAppController::class, 'pendientes']);
    Route::get('/{id}/pedidos', [VendedorAppController::class, 'pedidos']);
    Route::get('/{id}/pedidos/perfumes', [VendedorAppController::class, 'catalogoPedidos']);
    Route::post('/{id}/pedidos', [VendedorAppController::class, 'storePedido']);
    Route::post('/entregas/{entregaId}/confirmar', [VendedorAppController::class, 'confirmarEntrega']);
    Route::get('/{id}/stock', [VendedorAppController::class, 'stock']);
    Route::get('/{id}/perfumes-disponibles', [VendedorAppController::class, 'perfumesDisponibles']);
    Route::get('/{id}/clientes', [VendedorAppController::class, 'clientes']);
    Route::post('/{id}/clientes', [VendedorAppController::class, 'storeCliente']);
    Route::put('/{id}/clientes/{clienteId}', [VendedorAppController::class, 'updateCliente']);
    Route::delete('/{id}/clientes/{clienteId}', [VendedorAppController::class, 'destroyCliente']);
    Route::get('/{id}/ventas', [VendedorAppController::class, 'ventas']);
    Route::get('/{id}/comisiones', [VendedorAppController::class, 'comisiones']);
    Route::post('/{id}/comisiones/cobrar', [VendedorAppController::class, 'cobrarComision']);
    Route::get('/{id}/saldo-por-pagar', [VendedorAppController::class, 'saldoPorPagar']);
    Route::post('/{id}/saldo-por-pagar/{ventaId}/pagar', [VendedorAppController::class, 'pagarSaldoPorVenta']);
    Route::post('/{id}/ventas', [VendedorAppController::class, 'storeVenta']);
    Route::get('/{id}/ventas/{ventaId}/detalles', [VendedorAppController::class, 'detallesVenta']);
    Route::get('/{id}/ventas/{ventaId}/pagos', [VendedorAppController::class, 'pagosVenta']);
    Route::post('/{id}/ventas/{ventaId}/pagos', [VendedorAppController::class, 'storePagoVenta']);
    Route::get('/{id}/informacion', [VendedorAppController::class, 'informacion']);
});

Route::prefix('admin')->group(function () {
    Route::get('/resumen', [AdminEntregasController::class, 'resumen']);
    Route::get('/pedidos', [AdminEntregasController::class, 'pedidos']);
    Route::get('/ventas-por-vendedor', [AdminEntregasController::class, 'ventasPorVendedor']);
    Route::get('/comisiones/perfumes-vendidos', [AdminEntregasController::class, 'comisionesPerfumesVendidos']);
    Route::post('/comisiones', [AdminEntregasController::class, 'storeComisionPerfume']);
    Route::post('/comisiones/pagar', [AdminEntregasController::class, 'pagarComisionPerfume']);
    Route::get('/saldo-vendedor', [AdminEntregasController::class, 'saldoVendedor']);
    Route::get('/saldo-vendedor/pagos-por-confirmar', [AdminEntregasController::class, 'pagosVendedorPorConfirmar']);
    Route::post('/saldo-vendedor/pagos/{pagoId}/confirmar', [AdminEntregasController::class, 'confirmarPagoVendedor']);

    Route::get('/perfumes', [AdminEntregasController::class, 'perfumes']);
    Route::post('/perfumes', [AdminEntregasController::class, 'storePerfume']);
    Route::put('/perfumes/{id}', [AdminEntregasController::class, 'updatePerfume']);
    Route::delete('/perfumes/{id}', [AdminEntregasController::class, 'destroyPerfume']);

    Route::get('/vendedores', [AdminEntregasController::class, 'vendedores']);
    Route::post('/vendedores', [AdminEntregasController::class, 'storeVendedor']);
    Route::put('/vendedores/{id}', [AdminEntregasController::class, 'updateVendedor']);
    Route::delete('/vendedores/{id}', [AdminEntregasController::class, 'destroyVendedor']);

    Route::get('/clientes', [AdminEntregasController::class, 'clientes']);
    Route::post('/clientes', [AdminEntregasController::class, 'storeCliente']);
    Route::put('/clientes/{id}', [AdminEntregasController::class, 'updateCliente']);
    Route::delete('/clientes/{id}', [AdminEntregasController::class, 'destroyCliente']);

    Route::get('/entregas', [AdminEntregasController::class, 'entregas']);
    Route::post('/entregas', [AdminEntregasController::class, 'store']);
    Route::get('/entregas/{id}', [AdminEntregasController::class, 'show']);
    Route::put('/entregas/{id}/estado', [AdminEntregasController::class, 'updateEntregaEstado']);
    Route::delete('/entregas/{id}', [AdminEntregasController::class, 'destroyEntrega']);

    Route::get('/ventas', [AdminEntregasController::class, 'ventas']);
    Route::post('/ventas', [AdminEntregasController::class, 'storeVenta']);
    Route::get('/ventas/{id}/detalles', [AdminEntregasController::class, 'detallesVenta']);
    Route::get('/ventas/{id}/pagos', [AdminEntregasController::class, 'pagosVenta']);
    Route::post('/ventas/{id}/pagos', [AdminEntregasController::class, 'storePagoVenta']);
});
