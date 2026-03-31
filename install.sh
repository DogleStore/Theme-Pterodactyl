#!/bin/bash

# ==========================================================
# PTERODACTYL ULTIMATE MODIFIER - DOGLE STORE EXCLUSIVE
# Version: 2.0.0 (Production Ready)
# Optimized for: Ubuntu/Debian & Pterodactyl 1.11.x
# ==========================================================

# Jangan berhenti jika ada error ringan, tapi catat lognya
set -u

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}============================================================${NC}"
echo -e "${COLOR_BLUE}        PTERODACTYL MODERN UI & EXPIRED SYSTEM            ${NC}"
echo -e "${COLOR_PURPLE}============================================================${NC}"

# [Langkah 1: Validasi Lingkungan]
PANEL_PATH="/var/www/pterodactyl"

if [ "$EUID" -ne 0 ]; then 
  echo -e "${COLOR_RED}[ERROR] Harap jalankan script sebagai ROOT (sudo bash)${NC}"
  exit 1
fi

if [ ! -d "$PANEL_PATH" ]; then
    echo -e "${COLOR_RED}[ERROR] Panel tidak ditemukan di $PANEL_PATH${NC}"
    exit 1
fi

cd $PANEL_PATH

# [Langkah 2: Backup Cepat (Optimized)]
echo -e "${COLOR_YELLOW}[1/6] Menjalankan Backup Kilat (Excluding heavy folders)...${NC}"
# Kita lewati node_modules dan vendor karena itu bisa di-install ulang dan sangat berat untuk di-tar
TIMESTAMP=$(date +%s)
tar -czf "quick_backup_$TIMESTAMP.tar.gz" \
    --exclude='node_modules' \
    --exclude='vendor' \
    --exclude='.git' \
    --exclude='storage' \
    app/ resources/ database/ package.json tailwind.config.js 2>/dev/null

echo -e "${COLOR_GREEN}[SUCCESS] Backup selesai: quick_backup_$TIMESTAMP.tar.gz${NC}"

# [Langkah 3: Suntik Database & Backend]
echo -e "${COLOR_YELLOW}[2/6] Menyuntikkan Skema Database & Logic...${NC}"

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

# Update Server Model (Hanya jika belum ada)
if ! grep -q "expired_at" app/Models/Server.php; then
    sed -i "/'suspended',/a \ \ \ \ \ \ \ 'expired_at'," app/Models/Server.php
fi

# [Langkah 4: Suntik Modern UI Components]
echo -e "${COLOR_YELLOW}[3/6] Menyuntikkan Glassmorphism UI (React)...${NC}"

# ServerRow Component
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive } from 'react-feather';
import styled from 'styled-components';

const GlassCard = styled(NavLink)`
    background: rgba(15, 15, 20, 0.6);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.2s ease-in-out;
    &:hover { border-color: #06b6d4; transform: scale(1.02); background: rgba(20, 20, 25, 0.8); }
`;

export default ({ server }: { server: Server }) => {
    return (
        <GlassCard to={`/server/${server.uuid}`} className="rounded-2xl p-6 flex flex-col shadow-xl">
            <div className="flex justify-between items-start mb-6">
                <div className="flex items-center">
                    <div className="p-3 rounded-xl bg-cyan-500/10 text-cyan-400 mr-4"><ServerIcon size={24} /></div>
                    <div>
                        <h3 className="text-xl font-bold text-white truncate w-32">{server.name}</h3>
                        <p className="text-xs text-gray-500 uppercase font-bold tracking-widest">{server.node}</p>
                    </div>
                </div>
                <div className={`w-3 h-3 rounded-full ${server.isSuspended ? 'bg-red-500' : 'bg-green-500'} shadow-lg`} />
            </div>
            <div className="space-y-3 flex-grow">
                <div className="flex justify-between text-sm text-gray-400 font-medium">
                    <span className="flex items-center"><Cpu size={14} className="mr-2"/> CPU</span>
                    <span className="text-gray-200">{server.limits.cpu}%</span>
                </div>
                <div className="flex justify-between text-sm text-gray-400 font-medium">
                    <span className="flex items-center"><HardDrive size={14} className="mr-2"/> RAM</span>
                    <span className="text-gray-200">{server.limits.memory / 1024}GB</span>
                </div>
            </div>
            <div className="mt-6 pt-4 border-t border-white/5 flex justify-between items-center">
                <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest">Expiration Date</span>
                <span className="text-xs font-bold text-cyan-500 bg-cyan-500/10 px-3 py-1 rounded-full">
                    {server.expired_at ? format(new Date(server.expired_at), 'MMM dd, yyyy') : 'PERMANENT'}
                </span>
            </div>
        </GlassCard>
    );
};
EOF

# [Langkah 5: Database & Cache Maintenance]
echo -e "${COLOR_YELLOW}[4/6] Menjalankan Migrasi & Clear Cache...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# Register Cron
if ! grep -q "p:server:expiration" app/Console/Kernel.php; then
    sed -i "/schedule->command('p:backups:purge')->everyFiveMinutes();/a \ \ \ \ \ \ \ \$schedule->command('p:server:expiration')->everyMinute();" app/Console/Kernel.php
fi

# [Langkah 6: Build Process (Heavy)]
echo -e "${COLOR_YELLOW}[5/6] Membangun UI (Yarn Build Production)...${NC}"
echo -e "${COLOR_YELLOW}Mohon tunggu, proses ini memakan waktu 2-5 menit...${NC}"

export NODE_OPTIONS=--max_old_space_size=4096
yarn install --production=false --frozen-lockfile || yarn install
yarn build:production

# [Selesai]
echo -e "${COLOR_YELLOW}[6/6] Mengatur Ulang Hak Akses (Permissions)...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      MODIFIKASI BERHASIL DIINSTAL! - DOGLE STORE           ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
