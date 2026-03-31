#!/bin/bash

# ==========================================================
# PTERODACTYL HYPER-MODERN UI & EXPIRED SYSTEM
# Version: 6.0.0 (The Ultimate Transformation)
# Aesthetic: Cyber-Glass / Neon / Modern SaaS
# ==========================================================

set -e

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}============================================================${NC}"
echo -e "${COLOR_CYAN}        DOGLE STORE: PTERODACTYL HYPER-TRANSFORMATION       ${NC}"
echo -e "${COLOR_PURPLE}============================================================${NC}"

PANEL_PATH="/var/www/pterodactyl"
cd $PANEL_PATH

# [Langkah 1: Perbaikan Backend Transformer (SOLUSI ERROR 'IP')]
echo -e "${COLOR_BLUE}[1/7] Menghidupkan Kembali Data API (Fixing Transformer)...${NC}"
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
            'sftp_details' => [
                'ip' => $server->node->fqdn,
                'port' => $server->node->daemonSFTP,
            ],
            'description' => $server->description,
            'limits' => [
                'memory' => $server->memory,
                'swap' => $server->swap,
                'disk' => $server->disk,
                'io' => $server->io,
                'cpu' => $server->cpu,
            ],
            'feature_limits' => [
                'databases' => $server->database_limit,
                'allocations' => $server->allocation_limit,
                'backups' => $server->backup_limit,
            ],
            'expired_at' => $server->expired_at ? $server->expired_at->toIso8601String() : null,
            'status' => $server->status,
        ];
    }
}
EOF

# [Langkah 2: Suntik Dependencies & TS Definitions]
echo -e "${COLOR_BLUE}[2/7] Mengkonfigurasi TypeScript & Icons...${NC}"
sed -i '/"react-dom":/a \    "react-feather": "^2.0.9",' package.json

TS_FILE="resources/scripts/api/server/getServer.ts"
# Reset file agar bersih
cat << 'EOF' > $TS_FILE
import http, { FractalResponseData } from '@/api/http';
export interface Server {
    id: string;
    internalId: number;
    uuid: string;
    name: string;
    node: string;
    status: string | null;
    description: string | null;
    limits: { memory: number; swap: number; disk: number; io: number; cpu: number; };
    featureLimits: { databases: number; allocations: number; backups: number; };
    sftpDetails: { ip: string; port: number; };
    isSuspended: boolean;
    isInstalling: boolean;
    expiredAt: Date | null;
}
export const rawDataToServerObject = ({ attributes: data }: FractalResponseData): Server => ({
    id: data.uuid,
    internalId: data.internal_id,
    uuid: data.uuid,
    name: data.name,
    node: data.node,
    status: data.status,
    description: data.description,
    limits: { ...data.limits },
    featureLimits: { ...data.feature_limits },
    sftpDetails: { ...data.sftp_details },
    isSuspended: data.is_suspended,
    isInstalling: data.is_installing,
    expiredAt: data.expired_at ? new Date(data.expired_at) : null,
});
export default (uuid: string): Promise<[Server, string[]]> => {
    return new Promise((resolve, reject) => {
        http.get(`/api/client/servers/${uuid}`)
            .then(({ data }) => resolve([rawDataToServerObject(data), []]))
            .catch(reject);
    });
};
EOF

# [Langkah 3: Desain Dashboard Hyper-Modern]
echo -e "${COLOR_BLUE}[3/7] Mendesain Ulang Tampilan (Complex Glassmorphism)...${NC}"
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive, Zap, Shield } from 'react-feather';
import styled from 'styled-components';

const GlassCard = styled(NavLink)`
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.05) 0%, rgba(255, 255, 255, 0.01) 100%);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 24px;
    transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    position: relative;
    overflow: hidden;

    &:before {
        content: '';
        position: absolute;
        top: 0; left: -100%; width: 100%; height: 100%;
        background: linear-gradient(90deg, transparent, rgba(255,255,255,0.05), transparent);
        transition: 0.5s;
    }

    &:hover {
        transform: translateY(-8px) scale(1.02);
        border-color: rgba(6, 182, 212, 0.5);
        background: rgba(255, 255, 255, 0.07);
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 20px rgba(6, 182, 212, 0.2);
        &:before { left: 100%; }
    }
`;

export default ({ server }: { server: Server }) => {
    return (
        <GlassCard to={`/server/${server.uuid}`} className="p-7 flex flex-col h-full shadow-2xl">
            <div className="flex justify-between items-start mb-8">
                <div className="flex items-center">
                    <div className="p-4 rounded-2xl bg-gradient-to-br from-cyan-500/20 to-blue-600/10 text-cyan-400 mr-5">
                        <ServerIcon size={28} />
                    </div>
                    <div>
                        <h3 className="text-xl font-black text-white tracking-tight truncate w-36">{server.name}</h3>
                        <div className="flex items-center mt-1">
                            <Shield size={10} className="text-cyan-500/50 mr-1" />
                            <span className="text-[10px] text-gray-500 uppercase font-bold tracking-widest">{server.node}</span>
                        </div>
                    </div>
                </div>
                <div className={`flex items-center px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-tighter ${server.isSuspended ? 'bg-red-500/20 text-red-400' : 'bg-green-500/20 text-green-400'}`}>
                    <div className={`w-1.5 h-1.5 rounded-full mr-2 ${server.isSuspended ? 'bg-red-500 animate-pulse' : 'bg-green-500'}`} />
                    {server.isSuspended ? 'Suspended' : 'Online'}
                </div>
            </div>

            <div className="grid grid-cols-2 gap-4 mb-8">
                <div className="bg-white/5 rounded-2xl p-4 border border-white/5 hover:bg-white/10 transition-colors">
                    <div className="flex items-center text-gray-500 mb-1"><Cpu size={12} className="mr-2"/> <span className="text-[10px] font-bold uppercase">Processor</span></div>
                    <div className="text-lg font-black text-gray-100 font-mono">{server.limits.cpu}%</div>
                </div>
                <div className="bg-white/5 rounded-2xl p-4 border border-white/5 hover:bg-white/10 transition-colors">
                    <div className="flex items-center text-gray-500 mb-1"><Zap size={12} className="mr-2"/> <span className="text-[10px] font-bold uppercase">Memory</span></div>
                    <div className="text-lg font-black text-gray-100 font-mono">{server.limits.memory / 1024}GB</div>
                </div>
            </div>

            <div className="mt-auto pt-6 border-t border-white/10 flex justify-between items-center">
                <div className="flex items-center">
                    <Clock size={14} className="text-gray-500 mr-2" />
                    <span className="text-[11px] text-gray-400 font-bold uppercase tracking-widest">Expires</span>
                </div>
                <span className="text-xs font-black text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500">
                    {server.expiredAt ? format(new Date(server.expiredAt), 'MMM dd, yyyy') : 'UNLIMITED'}
                </span>
            </div>
        </GlassCard>
    );
};
EOF

# [Langkah 4: Global Styling Overhaul]
echo -e "${COLOR_BLUE}[4/7] Menyuntikkan Global CSS (Neon Effects)...${NC}"
cat << 'EOF' > resources/scripts/assets/css/GlobalStylesheet.ts
import { createGlobalStyle } from 'styled-components/macro';
export const GlobalStylesheet = createGlobalStyle`
    body {
        background-color: #050505 !important;
        background-image: radial-gradient(circle at 50% 0%, #111 0%, #050505 100%) !important;
        font-family: 'Inter', sans-serif !important;
    }
    .loading-spinner { border-color: #06b6d4 !important; border-top-color: transparent !important; }
    ::-webkit-scrollbar { width: 6px; }
    ::-webkit-scrollbar-thumb { background: #1a1a1a; border-radius: 10px; }
    ::-webkit-scrollbar-thumb:hover { background: #222; }
`;
EOF

# [Langkah 5: Backend & Database Migration]
echo -e "${COLOR_BLUE}[5/7] Sinkronisasi Database...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# [Langkah 6: Build Process (OpenSSL Fix)]
echo -e "${COLOR_BLUE}[6/7] Membangun Frontend (Yarn Build)...${NC}"
export NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096"
yarn install
yarn build:production

# [Langkah 7: Finalisasi]
echo -e "${COLOR_BLUE}[7/7] Mengatur Ulang Hak Akses...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      HYPER-TRANSFORMATION BERHASIL! SEMUA ERROR FIX.       ${NC}"
echo -e "${COLOR_GREEN}      TAMPILAN PANEL SEKARANG ADALAH LEVEL HIGH-END.       ${NC}"
echo -e "${COLOR_GREEN}      SILAHKAN REFRESH PANEL (CTRL+F5)                      ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
