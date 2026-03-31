#!/bin/bash

# ==========================================================
# PTERODACTYL MODIFIER - ABSOLUTE COMPLETION (V9)
# Version: 9.0.0 (Master Edition)
# Features: Full Feature Restore, Modern Grid, SaaS UI
# ==========================================================

set -e

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}============================================================${NC}"
echo -e "${COLOR_CYAN}        DOGLE STORE: ABSOLUTE PANEL TRANSFORMATION          ${NC}"
echo -e "${COLOR_PURPLE}============================================================${NC}"

PANEL_PATH="/var/www/pterodactyl"
cd $PANEL_PATH

# [Langkah 1: Restore Full Backend Data Schema]
echo -e "${COLOR_BLUE}[1/8] Memperbaiki API Transformer (Full Data Sync)...${NC}"
cat << 'EOF' > app/Transformers/Api/Client/ServerTransformer.php
<?php
namespace Pterodactyl\Transformers\Api\Client;
use Pterodactyl\Models\Server;
class ServerTransformer extends BaseClientTransformer {
    public function getResourceName(): string { return Server::RESOURCE_NAME; }
    public function transform(Server $server): array {
        $user = $this->request->user();
        return [
            'uuid' => $server->uuid,
            'internal_id' => $server->id,
            'is_suspended' => $server->is_suspended,
            'is_installing' => !$server->isInstalled(),
            'is_transferring' => !is_null($server->transfer),
            'is_node_under_maintenance' => (bool) $server->node->maintenance_mode,
            'is_owner' => $user->id === $server->owner_id,
            'name' => $server->name,
            'node' => $server->node->name,
            'sftp_details' => ['ip' => $server->node->fqdn, 'port' => $server->node->daemonSFTP],
            'description' => $server->description,
            'limits' => [
                'memory' => $server->memory, 'swap' => $server->swap, 'disk' => $server->disk,
                'io' => $server->io, 'cpu' => $server->cpu, 'threads' => $server->threads,
                'oom_disabled' => $server->oom_disabled,
            ],
            'feature_limits' => [
                'databases' => $server->database_limit,
                'allocations' => $server->allocation_limit,
                'backups' => $server->backup_limit,
            ],
            'expired_at' => $server->expired_at ? $server->expired_at->toIso8601String() : null,
            'status' => $server->status,
            'invocation' => $server->invocation,
            'docker_image' => $server->image,
            'egg_features' => $server->egg->inherited_features,
        ];
    }
}
EOF

# [Langkah 2: Restore Full TypeScript Interface]
echo -e "${COLOR_BLUE}[2/8] Memperbaiki TypeScript Core Interface...${NC}"
cat << 'EOF' > resources/scripts/api/server/getServer.ts
import http, { FractalResponseData, FractalResponseList } from '@/api/http';
import { rawDataToServerAllocation } from '@/api/transformers';

export interface Allocation { id: number; ip: string; alias: string | null; port: number; notes: string | null; isDefault: boolean; }

export interface Server {
    id: string; internalId: number; uuid: string; name: string; node: string;
    isNodeUnderMaintenance: boolean; status: string | null; description: string;
    sftpDetails: { ip: string; port: number; };
    limits: { memory: number; swap: number; disk: number; io: number; cpu: number; threads: string | null; oomDisabled: boolean; };
    featureLimits: { databases: number; allocations: number; backups: number; };
    isSuspended: boolean; isInstalling: boolean; isTransferring: boolean; isOwner: boolean;
    expiredAt: Date | null; allocations: Allocation[]; variables: any[]; eggFeatures: string[];
    invocation: string; dockerImage: string;
}

export const rawDataToServerObject = ({ attributes: data }: FractalResponseData): Server => ({
    id: data.uuid, internalId: data.internal_id, uuid: data.uuid, name: data.name, node: data.node,
    isNodeUnderMaintenance: data.is_node_under_maintenance, status: data.status,
    sftpDetails: { ...data.sftp_details }, description: data.description || '',
    limits: { ...data.limits, oomDisabled: data.limits.oom_disabled },
    featureLimits: { ...data.feature_limits },
    isSuspended: data.is_suspended, isInstalling: data.is_installing, isTransferring: data.is_transferring, isOwner: data.is_owner,
    expiredAt: data.expired_at ? new Date(data.expired_at) : null,
    invocation: data.invocation || '', dockerImage: data.docker_image || '',
    eggFeatures: data.egg_features || [],
    variables: ((data.relationships?.variables as FractalResponseList | undefined)?.data || []).map(v => v.attributes),
    allocations: ((data.relationships?.allocations as FractalResponseList | undefined)?.data || []).map(rawDataToServerAllocation),
});

export default (uuid: string): Promise<[Server, string[]]> => {
    return new Promise((resolve, reject) => {
        http.get(`/api/client/servers/${uuid}`)
            .then(({ data }) => resolve([rawDataToServerObject(data), []]))
            .catch(reject);
    });
};
EOF

# [Langkah 3: Dashboard Grid Modern Level Ultra]
echo -e "${COLOR_BLUE}[3/8] Menyuntikkan UI Dashboard Premium...${NC}"
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive, Globe, Zap, Settings } from 'react-feather';
import styled from 'styled-components';

const Card = styled(NavLink)`
    background: linear-gradient(145deg, rgba(23, 23, 23, 0.4), rgba(10, 10, 10, 0.6));
    backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    &:hover {
        border-color: #06b6d4;
        transform: translateY(-8px);
        background: rgba(30, 30, 30, 0.7);
        box-shadow: 0 20px 40px -10px rgba(0,0,0,0.8), 0 0 20px rgba(6, 182, 212, 0.15);
    }
`;

export default ({ server }: { server: Server }) => {
    const mainIp = server.allocations.find(a => a.isDefault);
    return (
        <Card to={`/server/${server.uuid}`} className="rounded-[2rem] p-7 flex flex-col h-full relative overflow-hidden group">
            <div className="flex justify-between items-start mb-8 relative z-10">
                <div className="flex items-center">
                    <div className="p-4 rounded-2xl bg-cyan-500/10 text-cyan-400 mr-5 group-hover:rotate-12 transition-transform">
                        <ServerIcon size={26} />
                    </div>
                    <div>
                        <h3 className="text-xl font-black text-white tracking-tight truncate w-36 leading-tight">{server.name}</h3>
                        <div className="flex items-center text-[10px] text-gray-500 font-bold uppercase tracking-widest mt-1">
                            <Globe size={10} className="mr-1 text-cyan-600" /> {server.node}
                        </div>
                    </div>
                </div>
                <div className={`w-3 h-3 rounded-full ${server.isSuspended ? 'bg-red-500' : 'bg-emerald-500 shadow-[0_0_10px_#10b981]'}`} />
            </div>

            <div className="grid grid-cols-2 gap-4 mb-8 relative z-10 flex-grow">
                <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                    <div className="flex items-center text-[9px] text-gray-500 font-black uppercase mb-1"><Cpu size={12} className="mr-2"/> CPU</div>
                    <div className="text-lg font-black text-gray-200">{server.limits.cpu}%</div>
                </div>
                <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                    <div className="flex items-center text-[9px] text-gray-500 font-black uppercase mb-1"><HardDrive size={12} className="mr-2"/> RAM</div>
                    <div className="text-lg font-black text-gray-200">{server.limits.memory / 1024}GB</div>
                </div>
            </div>

            <div className="pt-6 border-t border-white/5 flex justify-between items-center relative z-10">
                <div className="flex flex-col">
                    <span className="text-[9px] font-black text-gray-600 uppercase tracking-widest">Expiration</span>
                    <span className="text-xs font-black text-cyan-500 mt-0.5">
                        {server.expiredAt ? format(new Date(server.expiredAt), 'dd MMM yyyy') : 'LIFETIME'}
                    </span>
                </div>
                <div className="flex gap-2">
                    <div className="p-2.5 rounded-xl bg-white/5 text-gray-400 group-hover:text-cyan-400 transition-colors"><Zap size={16} /></div>
                </div>
            </div>
        </Card>
    );
};
EOF

# [Langkah 4: Global Styling FIX]
echo -e "${COLOR_BLUE}[4/8] Memperbaiki Styling Global...${NC}"
cat << 'EOF' > resources/scripts/assets/css/GlobalStylesheet.ts
import { createGlobalStyle } from 'styled-components/macro';
const GlobalStylesheet = createGlobalStyle`
    body { background-color: #080808 !important; font-family: 'Inter', sans-serif !important; }
    ::-webkit-scrollbar { width: 4px; }
    ::-webkit-scrollbar-thumb { background: #1a1a1a; border-radius: 10px; }
`;
export default GlobalStylesheet;
EOF

# [Langkah 5: Fix Dependencies]
echo -e "${COLOR_BLUE}[5/8] Sinkronisasi Library...${NC}"
sed -i '/"react-dom":/a \    "react-feather": "^2.0.9",' package.json

# [Langkah 6: Database Maintenance]
echo -e "${COLOR_BLUE}[6/8] Database & Cache Clear...${NC}"
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# [Langkah 7: Build Process]
echo -e "${COLOR_BLUE}[7/8] Membangun Frontend (Yarn Build Production)...${NC}"
export NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096"
yarn install
yarn build:production

# [Langkah 8: Permissions]
echo -e "${COLOR_BLUE}[8/8] Finalizing Permissions...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      SYSTEM FIXED! SEMUA FITUR TELAH KEMBALI NORMAL.       ${NC}"
echo -e "${COLOR_GREEN}      DASHBOARD PREMIUM SIAP DIGUNAKAN.                     ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
