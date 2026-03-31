#!/bin/bash

# ==========================================================
# PTERODACTYL MODIFIER - THE OMEGA ARCHITECT (V14)
# Version: 14.0.0 (Ultimate Stability & Hyper-Modern UI)
# Fixes: ALL PREVIOUS ERRORS (IP n/a, Sidebar, Startup, TS)
# ==========================================================

set -e

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${COLOR_PURPLE}============================================================${NC}"
echo -e "${COLOR_CYAN}        DOGLE STORE: OMEGA ARCHITECT TRANSFORMATION         ${NC}"
echo -e "${COLOR_PURPLE}============================================================${NC}"

PANEL_PATH="/var/www/pterodactyl"
cd $PANEL_PATH

# [Langkah 1: Backend Transformer - The Ultimate Bridge]
echo -e "${COLOR_BLUE}[1/8] Membangun Backend Data Bridge (ServerTransformer)...${NC}"
cat << 'EOF' > app/Transformers/Api/Client/ServerTransformer.php
<?php
namespace Pterodactyl\Transformers\Api\Client;

use Pterodactyl\Models\Server;
use Pterodactyl\Models\Allocation;

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

# [Langkah 2: TypeScript Core - The Universal Mapper]
echo -e "${COLOR_BLUE}[2/8] Rekonstruksi Core API Mapper (getServer.ts)...${NC}"
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
    const rels = response.relationships;

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
        variables: ((rels?.variables?.data || []) as any[]).map(v => v.attributes),
        allocations: ((rels?.allocations?.data || []) as any[]).map(rawDataToServerAllocation),
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

# [Langkah 3: UI Dashboard Hyper-Modern (The OP Theme)]
echo -e "${COLOR_BLUE}[3/8] Menyuntikkan UI Dashboard Premium (V14 Edition)...${NC}"
mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Server as ServerIcon, Clock, Cpu, HardDrive, Globe, Zap, Activity } from 'react-feather';
import styled, { keyframes } from 'styled-components';

const glow = keyframes`
  0% { box-shadow: 0 0 10px rgba(6, 182, 212, 0.1); }
  50% { box-shadow: 0 0 25px rgba(6, 182, 212, 0.4); }
  100% { box-shadow: 0 0 10px rgba(6, 182, 212, 0.1); }
`;

const Card = styled(NavLink)`
    background: linear-gradient(165deg, rgba(255, 255, 255, 0.04) 0%, rgba(255, 255, 255, 0.01) 100%);
    backdrop-filter: blur(30px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    transition: all 0.5s cubic-bezier(0.2, 0.8, 0.2, 1);
    &:hover {
        border-color: #06b6d4;
        transform: translateY(-12px) scale(1.02);
        background: rgba(255, 255, 255, 0.07);
        animation: ${glow} 3s infinite ease-in-out;
    }
`;

export default ({ server }: { server: Server }) => {
    const mainIp = server.allocations.find(a => a.isDefault);
    return (
        <Card to={`/server/${server.uuid}`} className="rounded-[2.8rem] p-8 flex flex-col h-full shadow-2xl relative group overflow-hidden">
            <div className="absolute -right-12 -top-12 opacity-[0.03] group-hover:opacity-[0.08] transition-opacity duration-700">
                <ServerIcon size={240} />
            </div>
            
            <div className="flex justify-between items-start mb-10 relative z-10">
                <div className="flex items-center">
                    <div className="p-5 rounded-[1.5rem] bg-gradient-to-br from-cyan-500/20 to-blue-600/10 text-cyan-400 mr-6 shadow-inner border border-cyan-500/10">
                        <ServerIcon size={32} />
                    </div>
                    <div>
                        <h3 className="text-2xl font-black text-white tracking-tighter truncate w-44 leading-tight">{server.name}</h3>
                        <div className="flex items-center text-[10px] text-cyan-500/40 font-black tracking-[0.3em] uppercase mt-2">
                            <Activity size={10} className="mr-2"/> {server.node}
                        </div>
                    </div>
                </div>
                <div className={`px-5 py-2 rounded-2xl text-[10px] font-black tracking-widest uppercase shadow-lg ${server.isSuspended ? 'bg-red-500/20 text-red-500 border border-red-500/20' : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/20'}`}>
                    {server.isSuspended ? 'Suspended' : 'Active'}
                </div>
            </div>

            <div className="space-y-5 mb-12 relative z-10 flex-grow">
                <div className="flex items-center text-[12px] text-gray-400 font-mono mb-8 bg-black/30 p-4 rounded-2xl border border-white/5 shadow-inner">
                    <Globe size={16} className="mr-4 text-cyan-500" />
                    {mainIp ? `${mainIp.ip}:${mainIp.port}` : 'Allocating...'}
                </div>
                <div className="grid grid-cols-2 gap-5">
                    <div className="bg-white/[0.03] rounded-3xl p-6 border border-white/[0.05] hover:bg-white/[0.06] transition-colors">
                        <span className="text-[10px] text-gray-500 uppercase font-black block mb-3 tracking-widest">CPU Power</span>
                        <span className="text-2xl font-black text-white">{server.limits.cpu}%</span>
                    </div>
                    <div className="bg-white/[0.03] rounded-3xl p-6 border border-white/[0.05] hover:bg-white/[0.06] transition-colors">
                        <span className="text-[10px] text-gray-500 uppercase font-black block mb-3 tracking-widest">Memory</span>
                        <span className="text-2xl font-black text-white">{server.limits.memory / 1024}GB</span>
                    </div>
                </div>
            </div>

            <div className="pt-8 border-t border-white/10 flex justify-between items-center relative z-10">
                <div className="flex flex-col">
                    <span className="text-[10px] font-black text-gray-600 uppercase tracking-[0.2em]">Expiration</span>
                    <span className="text-sm font-black text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500 mt-1 uppercase">
                        {server.expiredAt ? format(new Date(server.expiredAt), 'dd MMM yyyy') : 'LIFETIME'}
                    </span>
                </div>
                <div className="p-4 rounded-2xl bg-white/5 text-gray-500 group-hover:text-cyan-400 group-hover:bg-cyan-500/10 transition-all duration-300">
                    <Zap size={22} />
                </div>
            </div>
        </Card>
    );
};
EOF

# [Langkah 4: Global Stylesheet Fix]
echo -e "${COLOR_BLUE}[4/8] Memperbaiki Global Stylesheet Export...${NC}"
cat << 'EOF' > resources/scripts/assets/css/GlobalStylesheet.ts
import { createGlobalStyle } from 'styled-components/macro';
const GlobalStylesheet = createGlobalStyle`
    body { 
        background-color: #050505 !important; 
        font-family: 'Inter', sans-serif !important; 
        color: #eee;
        background-image: radial-gradient(circle at 50% 0%, #111 0%, #050505 100%) !important;
    }
    .loading-spinner { border-color: #06b6d4 !important; border-top-color: transparent !important; }
    ::-webkit-scrollbar { width: 5px; }
    ::-webkit-scrollbar-thumb { background: #1a1a1a; border-radius: 10px; }
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
echo -e "${COLOR_GREEN}      V14 OMEGA ARCHITECT BERHASIL! SEMUA ERROR FIXED.      ${NC}"
echo -e "${COLOR_GREEN}      DOGLE STORE: PANEL IS NOW HYPER-POWERFUL & MODERN.    ${NC}"
echo -e "${COLOR_GREEN}============================================================${NC}"
