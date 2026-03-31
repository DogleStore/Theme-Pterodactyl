#!/bin/bash

# ==========================================================
# PTERODACTYL MODIFIER - DEEP REPAIR VERSION (V4)
# Version: 4.0.0 (The Final Fix)
# Fixes: react-feather, TypeScript Types, & OpenSSL Legacy
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

# [Langkah 1: Injeksi Dependencies]
echo -e "${COLOR_YELLOW}[1/8] Menambahkan Library Icon (react-feather)...${NC}"
# Kita tambahkan secara manual ke package.json agar yarn mengenalinya
sed -i '/"react-dom":/a \    "react-feather": "^2.0.9",' package.json

# [Langkah 2: Perbaikan TypeScript Definitions (CRITICAL)]
echo -e "${COLOR_YELLOW}[2/8] Memperbaiki TypeScript Definitions...${NC}"
# File ini mengontrol apa saja yang boleh dibaca oleh React dari API
TS_FILE="resources/scripts/api/server/getServer.ts"

# Menambahkan isSuspended dan expiredAt ke Interface Server
if ! grep -q "expiredAt" "$TS_FILE"; then
    sed -i '/export interface Server {/a \    expiredAt: Date | null;\n    isSuspended: boolean;' "$TS_FILE"
fi

# [Langkah 3: Backend Logic & Transformer]
echo -e "${COLOR_YELLOW}[3/8] Menyuntikkan Skema Database & Transformer...${NC}"

# Laravel Migration
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
        Schema::table('servers', function (Blueprint $table) { $table->dropColumn('expired_at'); });
    }
}
EOF

# ServerTransformer Fix (Memastikan data dikirim ke frontend)
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

# [Langkah 4: UI Dashboard Baru (Fixing Properties)]
echo -e "${COLOR_YELLOW}[4/8] Menyuntikkan UI Dashboard (Fixed Syntax)...${NC}"
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
    transition: all 0.25s ease;
    &:hover { border-color: #06b6d4; transform: translateY(-4px); background: rgba(25, 25, 30, 0.9); }
`;

export default ({ server }: { server: Server }) => {
    // Pterodactyl API mengubah snake_case menjadi camelCase secara otomatis
    const isSuspended = server.isSuspended;
    const expirationDate = server.expiredAt;

    return (
        <GlassCard to={`/server/${server.uuid}`} className="rounded-2xl p-6 flex flex-col h-full shadow-2xl">
            <div className="flex justify-between items-start mb-6">
                <div className="flex items-center">
                    <div className="p-3 rounded-xl bg-cyan-500/10 text-cyan-400 mr-4"><ServerIcon size={24} /></div>
                    <div>
                        <h3 className="text-xl font-bold text-white truncate w-32 leading-tight">{server.name}</h3>
                        <p className="text-[10px] text-gray-500 uppercase font-black tracking-widest mt-1">{server.node}</p>
                    </div>
                </div>
                <div className={`w-3 h-3 rounded-full ${isSuspended ? 'bg-red-500 shadow-[0_0_12px_#ef4444]' : 'bg-green-500 shadow-[0_0_12px_#10b981]'}`} />
            </div>
            <div className="space-y-3 flex-grow">
                <div className="flex justify-between text-sm text-gray-400">
                    <span>CPU</span><span className="text-gray-200 font-bold">{server.limits.cpu}%</span>
                </div>
                <div className="flex justify-between text-sm text-gray-400">
                    <span>RAM</span><span className="text-gray-200 font-bold">{server.limits.memory / 1024}GB</span>
                </div>
            </div>
            <div className="mt-8 pt-5 border-t border-white/5 flex justify-between items-center">
                <div className="flex items-center text-gray-500 text-[10px] font-bold uppercase tracking-widest">
                    <Clock size={12} className="mr-2" /> Expires
                </div>
                <span className="text-[11px] font-black text-cyan-500 bg-cyan-500/5 px-3 py-1 rounded-lg border border-cyan-500/10 uppercase">
                    {expirationDate ? format(new Date(expirationDate), 'MMM dd, yyyy') : 'LIFETIME'}
                </span>
            </div>
        </GlassCard>
    );
};
EOF

# [Langkah 5: Database Maintenance]
echo -e "${COLOR_YELLOW}[5/8] Sinkronisasi Database...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# [Langkah 6: Persiapan Build Lingkungan]
echo -e "${COLOR_YELLOW}[6/8] Memperbaiki Lingkungan Build...${NC}"
export NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096"

# [Langkah 7: Build Process]
echo -e "${COLOR_YELLOW}[7/8] Membangun Aset Frontend (Yarn Build)...${NC}"
echo -e "${COLOR_YELLOW}Mohon tunggu sebentar...${NC}"

yarn install --frozen-lockfile || yarn install
yarn build:production

# [Langkah 8: Permissions]
echo -e "${COLOR_YELLOW}[8/8] Finalizing Permissions...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      BERHASIL! SEMUA ERROR TELAH DIPERBAIKI.               ${NC}"
echo -e "${COLOR_GREEN}      SILAHKAN REFRESH PANEL ANDA (CTRL+F5)                 ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
