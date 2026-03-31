#!/bin/bash

# ==========================================================
# PTERODACTYL MODIFIER - ULTIMATE REPAIR (V5)
# Version: 5.0.0 (The Final Solution)
# Fixes: TS2739 (Mapping Error), TypeScript Types, & Icons
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

# [Langkah 1: Backup]
echo -e "${COLOR_YELLOW}[1/8] Menjalankan Backup...${NC}"
tar -czf "backup_$(date +%s).tar.gz" --exclude='node_modules' --exclude='vendor' app/ resources/ database/ package.json 2>/dev/null

# [Langkah 2: Suntik Dependencies]
echo -e "${COLOR_YELLOW}[2/8] Menyiapkan Library Icons...${NC}"
# Pastikan react-feather ada di package.json
if ! grep -q "react-feather" package.json; then
    sed -i '/"react-dom":/a \    "react-feather": "^2.0.9",' package.json
fi

# [Langkah 3: Bedah Jantung TypeScript (CRITICAL FIX)]
echo -e "${COLOR_YELLOW}[3/8] Membedah core/getServer.ts (Fixing TS2739)...${NC}"
TS_FILE="resources/scripts/api/server/getServer.ts"

# A. Tambah ke Interface Server
if ! grep -q "expiredAt" "$TS_FILE"; then
    sed -i '/export interface Server {/a \    expiredAt: Date | null;\n    isSuspended: boolean;' "$TS_FILE"
fi

# B. Tambah ke Mapping rawDataToServerObject (Solusi Error TS2739)
# Kita masukkan data ke dalam return object function
if ! grep -q "expiredAt: data.expired_at" "$TS_FILE"; then
    sed -i "/allocations: ((data.relationships?.allocations/i \    expiredAt: data.expired_at ? new Date(data.expired_at) : null,\n    isSuspended: data.is_suspended," "$TS_FILE"
fi

# [Langkah 4: Backend Logic]
echo -e "${COLOR_YELLOW}[4/8] Menyuntikkan Skema Database & Transformer...${NC}"

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
    public function down() { Schema::table('servers', function (Blueprint $table) { $table->dropColumn('expired_at'); }); }
}
EOF

# ServerTransformer (Snake Case untuk API)
cat << 'EOF' > app/Transformers/Api/Client/ServerTransformer.php
<?php
namespace Pterodactyl\Transformers\Api\Client;
use Pterodactyl\Models\Server;
class ServerTransformer extends BaseClientTransformer {
    public function getResourceName(): string { return Server::RESOURCE_NAME; }
    public function transform(Server $server): array {
        return [
            'uuid' => $server->uuid,
            'identifier' => $server->uuid, // Alias untuk frontend
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

# [Langkah 5: UI Dashboard Baru]
echo -e "${COLOR_YELLOW}[5/8] Menyuntikkan Modern Dashboard Grid...${NC}"
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive } from 'react-feather';
import styled from 'styled-components';

const GlassCard = styled(NavLink)`
    background: rgba(15, 15, 20, 0.7);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    &:hover { border-color: #06b6d4; transform: translateY(-5px); background: rgba(20, 20, 25, 0.9); box-shadow: 0 20px 40px -15px rgba(0,0,0,0.7); }
`;

export default ({ server }: { server: Server }) => {
    return (
        <GlassCard to={`/server/${server.uuid}`} className="rounded-3xl p-7 flex flex-col h-full shadow-2xl overflow-hidden relative">
            <div className="flex justify-between items-start mb-8 relative z-10">
                <div className="flex items-center">
                    <div className="p-4 rounded-2xl bg-cyan-500/10 text-cyan-400 mr-5 shadow-inner"><ServerIcon size={28} /></div>
                    <div>
                        <h3 className="text-xl font-black text-white truncate w-36 leading-tight tracking-tight">{server.name}</h3>
                        <p className="text-[10px] text-cyan-500/50 uppercase font-bold tracking-[0.3em] mt-1">{server.node}</p>
                    </div>
                </div>
                <div className={`w-3 h-3 rounded-full ${server.isSuspended ? 'bg-red-500 shadow-[0_0_15px_#ef4444]' : 'bg-green-500 shadow-[0_0_15px_#10b981]'}`} />
            </div>
            
            <div className="space-y-4 flex-grow relative z-10">
                <div className="flex justify-between items-center text-sm">
                    <span className="text-gray-500 font-semibold flex items-center"><Cpu size={14} className="mr-2 opacity-50"/> CPU Limit</span>
                    <span className="text-gray-100 font-mono">{server.limits.cpu}%</span>
                </div>
                <div className="flex justify-between items-center text-sm">
                    <span className="text-gray-500 font-semibold flex items-center"><HardDrive size={14} className="mr-2 opacity-50"/> Memory</span>
                    <span className="text-gray-100 font-mono">{server.limits.memory / 1024}GB</span>
                </div>
            </div>

            <div className="mt-10 pt-6 border-t border-white/5 flex justify-between items-center relative z-10">
                <div className="flex flex-col">
                    <span className="text-[9px] font-black text-gray-600 uppercase tracking-widest">Server Status</span>
                    <span className="text-[11px] font-bold text-gray-300 uppercase italic">{server.status || 'Active'}</span>
                </div>
                <div className="text-right">
                    <span className="text-[9px] font-black text-gray-600 uppercase tracking-widest block">Expires In</span>
                    <span className="text-xs font-black text-cyan-400 bg-cyan-500/10 px-3 py-1 rounded-lg border border-cyan-500/20">
                        {server.expiredAt ? format(new Date(server.expiredAt), 'MMM dd, yyyy') : 'LIFETIME'}
                    </span>
                </div>
            </div>
        </GlassCard>
    );
};
EOF

# [Langkah 6: Database & Maintenance]
echo -e "${COLOR_YELLOW}[6/8] Menjalankan Migrasi & Cache Clear...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# [Langkah 7: Build Process dengan Fix OpenSSL]
echo -e "${COLOR_YELLOW}[7/8] Membangun Aset Frontend (Yarn Build Production)...${NC}"
export NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096"

yarn install
yarn build:production

# [Langkah 8: Permissions]
echo -e "${COLOR_YELLOW}[8/8] Finalizing Permissions...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      MODIFIKASI BERHASIL! SEMUA ERROR SUDAH FIXED.         ${NC}"
echo -e "${COLOR_GREEN}      SILAHKAN REFRESH PANEL (CTRL+F5)                      ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
