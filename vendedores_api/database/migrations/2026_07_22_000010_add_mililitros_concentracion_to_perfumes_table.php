<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('perfumes', function (Blueprint $table) {
            $table->unsignedSmallInteger('mililitros')->nullable()->after('marca');
            $table->string('concentracion', 60)->nullable()->after('mililitros');
        });
    }

    public function down(): void
    {
        Schema::table('perfumes', function (Blueprint $table) {
            $table->dropColumn(['mililitros', 'concentracion']);
        });
    }
};
