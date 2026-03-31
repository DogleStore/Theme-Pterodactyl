#!/bin/bash

# ==========================================================
# PTERODACTYL MODIFIER - ULTIMATE RECONSTRUCTION (V11)
# Version: 11.0.0 (The Final Fix)
# Status: PRODUCTION READY - FULLY COMPATIBLE
# ==========================================================

set -e

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}============================================================${NC}"
echo -e "${COLOR_CYAN}        DOGLE STORE: ULTIMATE PANEL TRANSFORMATION          ${NC}"
echo -e "${COLOR_PURPLE}============================================================${NC}"

PANEL_PATH="/var/www/pterodactyl"
cd $PANEL_PATH

# [Langkah 1: Fix Backend Transformer - Full Schema with Relationships]
echo -e "${COLOR_BLUE}[1/8] Memperbaiki Backend Transformer (Full Data Support)...${NC}"
cat << 'EOF' > app/Transformers/Api/Client/ServerTransformer.php
<?php
namespace Pterodactyl\Transformers\Api\Client;

use Pterodactyl\Models\Server;
use Pterodactyl\Transformers\Api\Client\AllocationTransformer;

class ServerTransformer extends BaseClientTransformer
{
    protected array $availableIncludes = ['allocations', 'variables', 'subusers', 'egg', 'node'];

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
                'threads' => $server->threads,
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

    public function includeAllocations(Server $server) {
        return $this->collection($server->allocations, $this->makeTransformer(AllocationTransformer::class), 'allocation');
    }

    public function includeVariables(Server $server) {
        return $this->collection($server->variables, $this->makeTransformer(EggVariableTransformer::class), 'egg_variable');
    }
}
EOF

# [Langkah 2: Fix TypeScript Core - SOLUSI ERROR TS2339 & STARTUP]
echo -e "${COLOR_BLUE}[2/8] Rekonstruksi TypeScript Core Interface (Fixing Build Errors)...${NC}"
cat << 'EOF' > resources/scripts/api/server/getServer.ts
import http from '@/api/http';
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

export const rawDataToServerObject = (response: any): Server => {
    const data = response.attributes;
    const relationships = response.relationships;

    return {
        id: data.uuid, internalId: data.internal_id, uuid: data.uuid, name: data.name, node: data.node,
        isNodeUnderMaintenance: data.is_node_under_maintenance, status: data.status,
        sftpDetails: { ...data.sftp_details }, description: data.description || '',
        limits: { ...data.limits, oomDisabled: data.limits.oom_disabled },
        featureLimits: { ...data.feature_limits },
        isSuspended: data.is_suspended, isInstalling: data.is_installing, 
        isTransferring: data.is_transferring, isOwner: data.is_owner,
        expiredAt: data.expired_at ? new Date(data.expired_at) : null,
        invocation: data.invocation || '', 
        dockerImage: data.docker_image || '',
        eggFeatures: data.egg_features || [],
        variables: ((relationships?.variables?.data || []) as any[]).map(v => v.attributes),
        allocations: ((relationships?.allocations?.data || []) as any[]).map(rawDataToServerAllocation),
    };
};

export default (uuid: string): Promise<[Server, string[]]> => {
    return new Promise((resolve, reject) => {
        http.get(`/api/client/servers/${uuid}?include=allocations,variables,egg,node`)
            .then(({ data }) => resolve([rawDataToServerObject(data), []]))
            .catch(reject);
    });
};
EOF

# [Langkah 3: Dashboard UI Modern (Fixed Dependencies)]
echo -e "${COLOR_BLUE}[3/8] Menyuntikkan Dashboard Grid UI Modern...${NC}"
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive, Globe, Zap } from 'react-feather';
import styled from 'styled-components';

const Card = styled(NavLink)`
    background: rgba(20, 20, 25, 0.7);
    backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.3s ease;
    &:hover { border-color: #06b6d4; transform: translateY(-5px); background: rgba(25, 25, 30, 0.9); }
`;

export default ({ server }: { server: Server }) => {
    const mainIp = server.allocations.find(a => a.isDefault);
    return (
        <Card to={`/server/${server.uuid}`} className="rounded-[2rem] p-7 flex flex-col h-full shadow-2xl relative group">
            <div className="flex justify-between items-start mb-6 relative z-10">
                <div className="flex items-center">
                    <div className="p-4 rounded-2xl bg-cyan-500/10 text-cyan-400 mr-5"><ServerIcon size={24} /></div>
                    <div>
                        <h3 className="text-xl font-bold text-white truncate w-32 tracking-tight leading-tight">{server.name}</h3>
                        <p className="text-[10px] text-gray-500 font-bold tracking-[0.2em] uppercase mt-1">{server.node}</p>
                    </div>
                </div>
                <div className={`w-3 h-3 rounded-full ${server.isSuspended ? 'bg-red-500 shadow-[0_0_10px_#ef4444]' : 'bg-green-500 shadow-[0_0_10px_#10b981]'}`} />
            </div>
            <div className="space-y-4 flex-grow relative z-10">
                <div className="flex items-center text-[11px] text-gray-400 font-mono mb-4">
                    <Globe size={14} className="mr-2 text-cyan-500" />
                    {mainIp ? `${mainIp.ip}:${mainIp.port}` : 'Allocating...'}
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                        <span className="text-[9px] text-gray-500 uppercase font-black block mb-1">CPU</span>
                        <span className="text-white font-bold">{server.limits.cpu}%</span>
                    </div>
                    <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                        <span className="text-[9px] text-gray-500 uppercase font-black block mb-1">RAM</span>
                        <span className="text-white font-bold">{server.limits.memory / 1024}GB</span>
                    </div>
                </div>
            </div>
            <div className="mt-8 pt-4 border-t border-white/5 flex justify-between items-center relative z-10">
                <div className="flex flex-col">
                    <span className="text-[9px] text-gray-600 font-black uppercase tracking-widest">Expiration</span>
                    <span className="text-xs font-bold text-cyan-400">
                        {server.expiredAt ? format(new Date(server.expiredAt), 'dd/MM/yyyy') : 'PERMANENT'}
                    </span>
                </div>
                <div className="p-2.5 rounded-xl bg-white/5 text-gray-400 group-hover:text-cyan-400 transition-colors"><Zap size={16} /></div>
            </div>
        </Card>
    );
};
EOF

# [Langkah 4: Global Styling Export Fix]
echo -e "${COLOR_BLUE}[4/8] Memperbaiki Global Stylesheet Export...${NC}"
cat << 'EOF' > resources/scripts/assets/css/GlobalStylesheet.ts
import { createGlobalStyle } from 'styled-components/macro';
const GlobalStylesheet = createGlobalStyle`
    body { background-color: #050505 !important; font-family: 'Inter', sans-serif !important; }
    .loading-spinner { border-color: #06b6d4 !important; border-top-color: transparent !important; }
`;
export default GlobalStylesheet;
EOF

# [Langkah 5: Fix Dependencies & Database]
echo -e "${COLOR_BLUE}[5/8] Sinkronisasi Library & Database...${NC}"
sed -i '/"react-dom":/a \    "react-feather": "^2.0.9",' package.json
php artisan migrate --force
php artisan view:clear
php artisan config:clear

# [Langkah 6: Build Process (LEGACY OPENSSL FIX)]
echo -e "${COLOR_BLUE}[6/8] Membangun Frontend (Yarn Build Production)...${NC}"
export NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096"
yarn install
yarn build:production

# [Langkah 7: Finalisasi Permissions]
echo -e "${COLOR_BLUE}[7/8] Finalizing Permissions...${NC}"
chown -R www-data:www-data $PANEL_PATH/*

echo -e "${COLOR_GREEN}============================================================${NC}"
echo -e "${COLOR_GREEN}      V11 FIX BERHASIL! SEMUA ERROR TELAH DIHANCURKAN.      ${NC}"
echo -e "${COLOR_GREEN}      DOGLE STORE: PANEL IS NOW HYPER-POWERFUL & MODERN.    ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
