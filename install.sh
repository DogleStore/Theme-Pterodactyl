#!/bin/bash

# ==========================================================
# PTERODACTYL MODERN UI & EXPIRED SYSTEM - UNIFIED INSTALLER
# Version: 1.0.0 (Stable)
# Target: Pterodactyl v1.11.x
# ==========================================================

set -e

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}------------------------------------------------------------${NC}"
echo -e "${COLOR_BLUE}   PTERODACTYL CORE MODIFICATION: EXPIRED DATE & MODERN UI   ${NC}"
echo -e "${COLOR_PURPLE}------------------------------------------------------------${NC}"

# 1. Detection & Validation
PANEL_PATH="/var/www/pterodactyl"
if [ ! -d "$PANEL_PATH" ]; then
    echo -e "${COLOR_RED}[ERROR] Lokasi panel tidak ditemukan di $PANEL_PATH${NC}"
    exit 1
fi

cd $PANEL_PATH

# 2. Backup (Ditingkatkan agar tidak crash)
echo -e "${COLOR_BLUE}[1/7] Menjalankan Backup Sistem...${NC}"
TIMESTAMP=$(date +%s)
# Kita gunakan --ignore-failed-read agar jika ada file yang berubah saat tar, script tidak berhenti
tar --ignore-failed-read -czf "backup_mod_$TIMESTAMP.tar.gz" app/ resources/ database/ package.json tailwind.config.js &> /dev/null || true
echo -e "${COLOR_GREEN}[SUCCESS] Backup tersimpan: backup_mod_$TIMESTAMP.tar.gz${NC}"

# 3. Database & Migration
echo -e "${COLOR_BLUE}[2/7] Menyuntikkan Skema Database (Expired Date)...${NC}"
cat << 'EOF' > database/migrations/2023_10_27_000000_add_expired_at_to_servers_table.php
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
class AddExpiredAtToServersTable extends Migration {
    public function up() {
        Schema::table('servers', function (Blueprint $table) {
            $table->timestamp('expired_at')->nullable()->after('updated_at');
        });
    }
    public function down() {
        Schema::table('servers', function (Blueprint $table) {
            $table->dropColumn('expired_at');
        });
    }
}
EOF

# 4. Backend Logic & Cronjob
echo -e "${COLOR_BLUE}[3/7] Menyuntikkan Sistem Auto-Suspension...${NC}"
mkdir -p app/Console/Commands/Server
cat << 'EOF' > app/Console/Commands/Server/CheckServerExpirationCommand.php
<?php
namespace Pterodactyl\Console\Commands\Server;
use Illuminate\Console\Command;
use Pterodactyl\Models\Server;
use Pterodactyl\Services\Servers\SuspensionService;
use Carbon\Carbon;
class CheckServerExpirationCommand extends Command {
    protected $signature = 'p:server:expiration';
    protected $description = 'Checks for expired servers and suspends them automatically.';
    protected $suspensionService;
    public function __construct(SuspensionService $suspensionService) {
        parent::__construct();
        $this->suspensionService = $suspensionService;
    }
    public function handle() {
        $expiredServers = Server::query()
            ->where('status', '!=', Server::STATUS_SUSPENDED)
            ->whereNotNull('expired_at')
            ->where('expired_at', '<', Carbon::now())
            ->get();
        foreach ($expiredServers as $server) {
            $this->warn("Suspending Server: {$server->name} (ID: {$server->id}) - Expired");
            $this->suspensionService->toggle($server, SuspensionService::ACTION_SUSPEND);
        }
    }
}
EOF

# Update Server Model (Tambah expired_at ke fillable)
sed -i "/'suspended',/a \ \ \ \ \ \ \ 'expired_at'," app/Models/Server.php

# Update API Transformer (Agar frontend bisa baca tanggal)
cat << 'EOF' > app/Transformers/Api/Client/ServerTransformer.php
<?php
namespace Pterodactyl\Transformers\Api\Client;
use Pterodactyl\Models\Server;
class ServerTransformer extends BaseClientTransformer {
    public function getResourceName(): string { return Server::RESOURCE_NAME; }
    public function transform(Server $server): array {
        return [
            'uuid' => $server->uuid,
            'internal_id' => $server->id,
            'is_suspended' => $server->is_suspended,
            'is_installing' => !$server->isInstalled(),
            'name' => $server->name,
            'node' => $server->node->name,
            'description' => $server->description,
            'limits' => [
                'memory' => $server->memory,
                'swap' => $server->swap,
                'disk' => $server->disk,
                'cpu' => $server->cpu,
            ],
            'expired_at' => $server->expired_at ? $server->expired_at->toIso8601String() : null,
            'status' => $server->status,
        ];
    }
}
EOF

# 5. UI/Frontend - Tailwind & React Glassmorphism
echo -e "${COLOR_BLUE}[4/7] Menyuntikkan Modern Glassmorphism UI...${NC}"

# Tailwind Configuration
cat << 'EOF' > tailwind.config.js
module.exports = {
    content: ['./resources/views/**/*.blade.php', './resources/scripts/**/*.tsx'],
    theme: {
        extend: {
            colors: {
                gray: { 900: '#09090b', 800: '#131316', 700: '#1c1c21' },
                cyan: { 500: '#06b6d4' }
            },
            backgroundImage: { 'glass-gradient': 'linear-gradient(135deg, rgba(255, 255, 255, 0.05) 0%, rgba(255, 255, 255, 0.01) 100%)' }
        },
    },
    plugins: [require('@tailwindcss/forms'), require('@tailwindcss/line-clamp')],
};
EOF

# ServerRow React Component
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock } from 'react-feather';
import styled from 'styled-components';

const GlassCard = styled(NavLink)`
    background: rgba(255, 255, 255, 0.03);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    &:hover { border-color: rgba(6, 182, 212, 0.5); transform: translateY(-2px); }
`;

export default ({ server }: { server: Server }) => {
    return (
        <GlassCard to={`/server/${server.uuid}`} className="rounded-xl p-5 flex flex-col transition-all">
            <div className="flex justify-between items-start mb-4">
                <div className="flex items-center">
                    <div className="p-2 rounded-lg bg-cyan-500/10 text-cyan-500 mr-3"><ServerIcon size={20} /></div>
                    <h3 className="text-lg font-bold text-gray-100 truncate w-32">{server.name}</h3>
                </div>
                <div className={`w-2 h-2 rounded-full ${server.isSuspended ? 'bg-red-500' : 'bg-green-500 shadow-[0_0_8px_#10b981]'}`} />
            </div>
            <div className="text-xs text-gray-400 space-y-2 flex-grow">
                <p>CPU: {server.limits.cpu}% | RAM: {server.limits.memory / 1024}GB</p>
                <div className="pt-4 border-t border-white/5 flex justify-between items-center">
                    <span className="flex items-center uppercase tracking-tighter text-[10px]"><Clock size={12} className="mr-1"/> Expires</span>
                    <span className="text-cyan-400 font-mono italic">
                        {server.expired_at ? format(new Date(server.expired_at), 'dd/MM/yyyy') : 'Never'}
                    </span>
                </div>
            </div>
        </GlassCard>
    );
};
EOF

# 6. Database Migration & Cache Clearing
echo -e "${COLOR_BLUE}[5/7] Sinkronisasi Database & Cache...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# Tambahkan ke scheduler jika belum ada
if ! grep -q "p:server:expiration" app/Console/Kernel.php; then
    sed -i "/schedule->command('p:backups:purge')->everyFiveMinutes();/a \ \ \ \ \ \ \ \$schedule->command('p:server:expiration')->everyMinute();" app/Console/Kernel.php
fi

# 7. Build Frontend (Bagian paling berat)
echo -e "${COLOR_BLUE}[6/7] Membangun Aset Frontend (Yarn Build)...${NC}"
export NODE_OPTIONS=--max_old_space_size=4096
yarn install || { echo -e "${COLOR_RED}Gagal install dependencies${NC}"; exit 1; }
yarn build:production || { echo -e "${COLOR_RED}Gagal build production aset${NC}"; exit 1; }

# Finishing
echo -e "${COLOR_BLUE}[7/7] Finishing Permissions...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}------------------------------------------------------------${NC}"
echo -e "${COLOR_GREEN}      INSTALLASI SELESAI! PANEL ANDA SEKARANG MODERN        ${NC}"
echo -e "${COLOR_GREEN}------------------------------------------------------------${NC}"
