#!/bin/bash

# ==========================================================
# PTERODACTYL ULTIMATE MODIFIER - OPENSSL FIX VERSION
# Version: 3.0.0 (Fix: ERR_OSSL_EVP_UNSUPPORTED)
# Optimized for: Ubuntu 24.04 / Node 18+ / OpenSSL 3.0
# ==========================================================

set -e

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}============================================================${NC}"
echo -e "${COLOR_BLUE}        PTERODACTYL MODERN UI & EXPIRED SYSTEM            ${NC}"
echo -e "${COLOR_PURPLE}============================================================${NC}"

PANEL_PATH="/var/www/pterodactyl"
cd $PANEL_PATH

# [Langkah 1: Backup Cepat]
echo -e "${COLOR_YELLOW}[1/7] Menjalankan Backup...${NC}"
tar -czf "backup_$(date +%s).tar.gz" --exclude='node_modules' --exclude='vendor' app/ resources/ database/ package.json tailwind.config.js 2>/dev/null

# [Langkah 2: Suntik Database & Backend]
echo -e "${COLOR_YELLOW}[2/7] Menyuntikkan Skema Database & Logic...${NC}"

# Migration
cat << 'EOF' > database/migrations/2023_10_27_000000_add_expired_at_to_servers_table.php
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
class AddExpiredAtToServersTable extends Migration {
    public function up() {
        if (!Schema::hasColumn('servers', 'expired_at')) {
            Schema::table('servers', function (Blueprint $table) {
                $table->timestamp('expired_at')->nullable()->after('updated_at');
            });
        }
    }
    public function down() {
        Schema::table('servers', function (Blueprint $table) {
            $table->dropColumn('expired_at');
        });
    }
}
EOF

# Expiration Command
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
    protected $description = 'Suspend expired servers.';
    protected $suspensionService;
    public function __construct(SuspensionService $suspensionService) {
        parent::__construct();
        $this->suspensionService = $suspensionService;
    }
    public function handle() {
        $expired = Server::query()->where('status', '!=', Server::STATUS_SUSPENDED)
            ->whereNotNull('expired_at')->where('expired_at', '<', Carbon::now())->get();
        foreach ($expired as $server) {
            $this->suspensionService->toggle($server, SuspensionService::ACTION_SUSPEND);
        }
    }
}
EOF

# [Langkah 3: Suntik Modern UI Dashboard]
echo -e "${COLOR_YELLOW}[3/7] Menyuntikkan UI Dashboard Baru...${NC}"
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive } from 'react-feather';
import styled from 'styled-components';

const GlassCard = styled(NavLink)`
    background: rgba(18, 18, 23, 0.7);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    &:hover { border-color: #06b6d4; transform: translateY(-4px); background: rgba(25, 25, 30, 0.9); box-shadow: 0 10px 30px -10px rgba(0,0,0,0.5); }
`;

export default ({ server }: { server: Server }) => {
    return (
        <GlassCard to={`/server/${server.uuid}`} className="rounded-2xl p-6 flex flex-col h-full shadow-2xl">
            <div className="flex justify-between items-start mb-6">
                <div className="flex items-center">
                    <div className="p-3 rounded-xl bg-cyan-500/10 text-cyan-400 mr-4 shadow-inner"><ServerIcon size={24} /></div>
                    <div>
                        <h3 className="text-xl font-bold text-white truncate w-32 leading-tight">{server.name}</h3>
                        <p className="text-[10px] text-gray-500 uppercase font-black tracking-[0.2em] mt-1">{server.node}</p>
                    </div>
                </div>
                <div className={`w-3 h-3 rounded-full ${server.isSuspended ? 'bg-red-500 shadow-[0_0_12px_rgba(239,68,68,0.5)]' : 'bg-green-500 shadow-[0_0_12px_rgba(16,185,129,0.5)]'}`} />
            </div>
            <div className="space-y-3 flex-grow">
                <div className="flex justify-between text-sm">
                    <span className="text-gray-500 font-medium">CPU Usage</span>
                    <span className="text-gray-200 font-bold">{server.limits.cpu}%</span>
                </div>
                <div className="flex justify-between text-sm">
                    <span className="text-gray-500 font-medium">Memory</span>
                    <span className="text-gray-200 font-bold">{server.limits.memory / 1024}GB</span>
                </div>
            </div>
            <div className="mt-8 pt-5 border-t border-white/5 flex justify-between items-center">
                <div className="flex items-center text-gray-500">
                    <Clock size={12} className="mr-2" />
                    <span className="text-[10px] font-bold uppercase tracking-widest">Expires</span>
                </div>
                <span className="text-[11px] font-black text-cyan-500 bg-cyan-500/5 px-3 py-1 rounded-lg border border-cyan-500/10">
                    {server.expired_at ? format(new Date(server.expired_at), 'MMM dd, yyyy') : 'LIFETIME'}
                </span>
            </div>
        </GlassCard>
    );
};
EOF

# [Langkah 4: Sinkronisasi Database]
echo -e "${COLOR_YELLOW}[4/7] Sinkronisasi Database & Cache...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# [Langkah 5: Perbaikan Lingkungan Node (CRITICAL FIX)]
echo -e "${COLOR_YELLOW}[5/7] Memperbaiki Lingkungan Node (OpenSSL Legacy)...${NC}"
# Inilah obat untuk error ERR_OSSL_EVP_UNSUPPORTED
export NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096"

# Update Browserslist agar tidak ada warning
npx update-browserslist-db@latest --yes || true

# [Langkah 6: Build Process]
echo -e "${COLOR_YELLOW}[6/7] Membangun Aset Frontend (Yarn Build)...${NC}"
echo -e "${COLOR_YELLOW}Mohon tunggu, proses ini memakan waktu 2-5 menit...${NC}"

yarn install
yarn build:production

# [Langkah 7: Permissions]
echo -e "${COLOR_YELLOW}[7/7] Finalizing Permissions...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      MODIFIKASI BERHASIL DIINSTAL! - DOGLE STORE           ${NC}"
echo -e "${COLOR_GREEN}      SILAHKAN REFRESH PANEL ANDA (CTRL+F5)                 ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
