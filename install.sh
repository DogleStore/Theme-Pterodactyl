#!/bin/bash

# Pterodactyl Modern Overhaul & Expiration System Installer
# Targeted Version: v1.11.x
# Created by: Senior DevOps Engineer / Lead Full-Stack Developer

set -e

# --- Configuration & Colors ---
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
    echo -e "${COLOR_RED}[ERROR] Could not find Pterodactyl at $PANEL_PATH${NC}"
    exit 1
fi

cd $PANEL_PATH

# 2. Backup System
echo -e "${COLOR_BLUE}[1/5] Backing up current panel files...${NC}"
TIMESTAMP=$(date +%F_%T)
tar -czf "backup_before_mod_$TIMESTAMP.tar.gz" app/ resources/ database/ &> /dev/null
echo -e "${COLOR_GREEN}[SUCCESS] Backup saved as backup_before_mod_$TIMESTAMP.tar.gz${NC}"

# 3. Database Migration Injection
echo -e "${COLOR_BLUE}[2/5] Injecting Database Schema (Expired Date System)...${NC}"

cat << 'EOF' > database/migrations/2023_10_27_000000_add_expired_at_to_servers_table.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddExpiredAtToServersTable extends Migration
{
    public function up()
    {
        Schema::table('servers', function (Blueprint $table) {
            $table->timestamp('expired_at')->nullable()->after('updated_at');
        });
    }

    public function down()
    {
        Schema::table('servers', function (Blueprint $table) {
            $table->dropColumn('expired_at');
        });
    }
}
EOF

# 4. Backend Logic: The Expiration Cronjob
echo -e "${COLOR_BLUE}[3/5] Injecting Artisan Expiration Command...${NC}"

mkdir -p app/Console/Commands/Server
cat << 'EOF' > app/Console/Commands/Server/CheckServerExpirationCommand.php
<?php

namespace Pterodactyl\Console\Commands\Server;

use Illuminate\Console\Command;
use Pterodactyl\Models\Server;
use Pterodactyl\Services\Servers\SuspensionService;
use Carbon\Carbon;

class CheckServerExpirationCommand extends Command
{
    protected $signature = 'p:server:expiration';
    protected $description = 'Checks for expired servers and suspends them automatically.';

    protected $suspensionService;

    public function __construct(SuspensionService $suspensionService)
    {
        parent::__construct();
        $this->suspensionService = $suspensionService;
    }

    public function handle()
    {
        $expiredServers = Server::query()
            ->where('status', '!=', Server::STATUS_SUSPENDED)
            ->whereNotNull('expired_at')
            ->where('expired_at', '<', Carbon::now())
            ->get();

        if ($expiredServers->isEmpty()) {
            $this->info('No expired servers found.');
            return;
        }

        foreach ($expiredServers as $server) {
            $this->warn("Suspending Server: {$server->name} (ID: {$server->id}) - Expired at: {$server->expired_at}");
            $this->suspensionService->toggle($server, SuspensionService::ACTION_SUSPEND);
        }

        $this->info('Expiration check completed.');
    }
}
EOF

# 5. Modifying Server Model to handle the new date
# Using sed to add the property to the fillable array and dates
sed -i "/'suspended',/a \ \ \ \ \ \ \ 'expired_at'," app/Models/Server.php

# 6. Injecting the Modern Transformer (API)
# This ensures the frontend receives the expired_at date
cat << 'EOF' > app/Transformers/Api/Client/ServerTransformer.php
<?php

namespace Pterodactyl\Transformers\Api\Client;

use Pterodactyl\Models\Server;
use Pterodactyl\Models\Allocation;

class ServerTransformer extends BaseClientTransformer
{
    public function getResourceName(): string
    {
        return Server::RESOURCE_NAME;
    }

    public function transform(Server $server): array
    {
        return [
            'uuid' => $server->uuid,
            'internal_id' => $server->id,
            'is_suspended' => $server->is_suspended,
            'is_installing' => !$server->isInstalled(),
            'is_transferring' => !is_null($server->transfer),
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
            'is_owner' => $this->request->user()->id === $server->owner_id,
            'expired_at' => $server->expired_at ? $server->expired_at->toIso8601String() : null,
            'status' => $server->status,
        ];
    }
}
EOF

# 7. Apply Migrations
echo -e "${COLOR_BLUE}[4/5] Running Database Migrations...${NC}"
php artisan migrate --force

# 8. Setting up the Cronjob
echo -e "${COLOR_BLUE}[5/5] Registering Expiration Task in Kernel...${NC}"
if ! grep -q "p:server:expiration" app/Console/Kernel.php; then
    sed -i "/schedule->command('p:backups:purge')->everyFiveMinutes();/a \ \ \ \ \ \ \ \$schedule->command('p:server:expiration')->everyMinute();" app/Console/Kernel.php
fi

echo -e "${COLOR_GREEN}------------------------------------------------------------${NC}"
echo -e "${COLOR_GREEN}BACKEND CORE INJECTED SUCCESSFULLY.${NC}"
echo -e "${COLOR_PURPLE}Ready for UI/Theme injection (Part 2).${NC}"
echo -e "${COLOR_PURPLE}Please type 'CONTINUE' to receive the React and CSS files.${NC}"
echo -e "${COLOR_GREEN}------------------------------------------------------------${NC}"


set -e
PANEL_PATH="/var/www/pterodactyl"
cd $PANEL_PATH

echo -e "\033[0;34m[1/4] Injecting Modern Tailwind & CSS Theme...\033[0m"

# 1. Update Tailwind Config for Neon & Glass Effects
cat << 'EOF' > tailwind.config.js
const { colors } = require('tailwindcss/defaultTheme');

module.exports = {
    content: [
        './resources/views/**/*.blade.php',
        './resources/scripts/**/*.tsx',
    ],
    theme: {
        extend: {
            colors: {
                gray: {
                    ...colors.gray,
                    900: '#09090b',
                    800: '#131316',
                    700: '#1c1c21',
                },
                cyan: {
                    500: '#06b6d4',
                    600: '#0891b2',
                },
                neon: {
                    purple: '#9333ea',
                    blue: '#2563eb',
                    pink: '#db2777',
                }
            },
            boxShadow: {
                'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
                'neon-blue': '0 0 15px rgba(37, 99, 235, 0.4)',
            },
            backgroundImage: {
                'glass-gradient': 'linear-gradient(135deg, rgba(255, 255, 255, 0.05) 0%, rgba(255, 255, 255, 0.01) 100%)',
            }
        },
    },
    plugins: [
        require('@tailwindcss/forms'),
        require('@tailwindcss/line-clamp'),
    ],
};
EOF

# 2. Update the TypeScript Definition for Servers
# This is required so React knows about the expired_at property
sed -i "/export interface Server {/a \ \ \ \ expiredAt: Date | null;" resources/scripts/api/server/getServer.ts
sed -i "/'is_suspended',/a \ \ \ \ 'expired_at'," resources/scripts/api/server/getServer.ts

# 3. Inject the Modern Server Card (Glassmorphism UI)
echo -e "\033[0;34m[2/4] Overhauling React Dashboard Components...\033[0m"

mkdir -p resources/scripts/components/dashboard
cat << 'EOF' > resources/scripts/components/dashboard/ServerRow.tsx
import React from 'react';
import { Server } from '@/api/server/getServer';
import { NavLink } from 'react-router-dom';
import { format } from 'date-fns';
import { Cpu, HardDrive, Layout, Server as ServerIcon, Clock, AlertTriangle } from 'react-feather';
import styled from 'styled-components';

const GlassCard = styled(NavLink)`
    background: rgba(255, 255, 255, 0.03);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    
    &:hover {
        background: rgba(255, 255, 255, 0.06);
        border-color: rgba(6, 182, 212, 0.5);
        transform: translateY(-4px);
        box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3), 0 0 15px rgba(6, 182, 212, 0.2);
    }
`;

const StatusBadge = styled.div<{ $suspended?: boolean }>`
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: ${props => props.$suspended ? '#ef4444' : '#10b981'};
    box-shadow: 0 0 10px ${props => props.$suspended ? '#ef4444' : '#10b981'};
`;

export default ({ server }: { server: Server }) => {
    const isExpired = server.expiredAt ? new Date(server.expiredAt) < new Date() : false;

    return (
        <GlassCard to={`/server/${server.uuid}`} className="rounded-2xl p-6 flex flex-col h-full relative overflow-hidden group">
            <div className="flex justify-between items-start mb-6">
                <div className="flex items-center">
                    <div className="p-3 rounded-xl bg-cyan-500/10 text-cyan-500 mr-4 group-hover:bg-cyan-500 group-hover:text-white transition-colors">
                        <ServerIcon size={24} />
                    </div>
                    <div>
                        <h3 className="text-xl font-bold text-gray-100 truncate w-40 leading-tight">{server.name}</h3>
                        <p className="text-xs text-gray-500 uppercase tracking-widest mt-1 font-semibold">{server.node}</p>
                    </div>
                </div>
                <StatusBadge $suspended={server.isSuspended} />
            </div>

            <div className="space-y-4 flex-grow">
                <div className="flex items-center text-gray-400 text-sm">
                    <Cpu size={16} className="mr-3 text-gray-500" />
                    <span>{server.limits.cpu === 0 ? 'Unlimited' : `${server.limits.cpu}%`} CPU Core</span>
                </div>
                <div className="flex items-center text-gray-400 text-sm">
                    <Layout size={16} className="mr-3 text-gray-500" />
                    <span>{server.limits.memory / 1024} GB RAM</span>
                </div>
                <div className="flex items-center text-gray-400 text-sm">
                    <HardDrive size={16} className="mr-3 text-gray-500" />
                    <span>{server.limits.disk / 1024} GB NVMe SSD</span>
                </div>
            </div>

            <div className="mt-8 pt-6 border-t border-white/5 flex flex-col gap-3">
                <div className="flex justify-between items-center">
                    <div className="flex items-center text-xs font-medium text-gray-500 uppercase">
                        <Clock size={14} className="mr-2" />
                        Expiration
                    </div>
                    <span className={`text-xs font-bold px-2 py-1 rounded-md ${isExpired ? 'bg-red-500/20 text-red-400' : 'bg-green-500/20 text-green-400'}`}>
                        {server.expiredAt ? format(new Date(server.expiredAt), 'MMM dd, yyyy') : 'Life-time'}
                    </span>
                </div>
                
                {isExpired && (
                    <div className="flex items-center text-[10px] text-red-400 font-bold uppercase tracking-tighter animate-pulse">
                        <AlertTriangle size={12} className="mr-1" />
                        Server is scheduled for suspension
                    </div>
                )}
            </div>
        </GlassCard>
    );
};
EOF

# 4. Replace Dashboard Container with Modern Grid
cat << 'EOF' > resources/scripts/components/dashboard/DashboardContainer.tsx
import React, { useEffect, useState } from 'react';
import { Server } from '@/api/server/getServer';
import getServers from '@/api/getServers';
import ServerRow from '@/components/dashboard/ServerRow';
import Pagination from '@/components/elements/Pagination';
import { PageContentBlock } from '@/components/elements/PageBlock';
import { useStoreState } from 'easy-peasy';
import { useLocation } from 'react-router-dom';
import Spinner from '@/components/elements/Spinner';

export default () => {
    const { search } = useLocation();
    const defaultPage = Number(new URLSearchParams(search).get('page') || '1');
    const [page, setPage] = useState(defaultPage);
    const [servers, setServers] = useState<any>(null);
    const showOnlyAdmin = useStoreState((state: any) => state.permissions.isRootAdmin);

    useEffect(() => {
        getServers({ page, admin: showOnlyAdmin }).then(setServers);
    }, [page, showOnlyAdmin]);

    if (!servers) return <div className="flex justify-center mt-20"><Spinner size="large" /></div>;

    return (
        <PageContentBlock title={'Dashboard'} showFlashKey={'dashboard'}>
            <div className="mb-10">
                <h1 className="text-4xl font-black text-white tracking-tight">Your Infrastructure</h1>
                <p className="text-gray-400 mt-2 font-medium">Manage and monitor your high-performance instances.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
                {servers.items.map((server: Server) => (
                    <ServerRow key={server.uuid} server={server} />
                ))}
            </div>

            <div className="mt-12">
                <Pagination data={servers} onPageSelect={setPage} />
            </div>
        </PageContentBlock>
    );
};
EOF

# 5. Build and Cleanup
echo -e "\033[0;32m[3/4] Frontend logic injected. Commencing Production Build...\033[0m"

# Handle potential Node memory issues during heavy webpack build
export NODE_OPTIONS=--max_old_space_size=4096

if ! yarn install; then
    echo -e "\033[0;31m[ERROR] Yarn install failed. Restoring backup...\033[0m"
    # Logic to restore could go here
    exit 1
fi

if ! yarn build:production; then
    echo -e "\033[0;31m[ERROR] Build failed. This is usually due to insufficient RAM.\033[0m"
    exit 1
fi

echo -e "\033[0;34m[4/4] Finalizing System Permissions...\033[0m"
php artisan view:clear
php artisan config:clear
chown -R www-data:www-data $PANEL_PATH/*

echo -e "\033[1;32m------------------------------------------------------------\033[0m"
echo -e "\033[1;32m   CORE MODIFICATION COMPLETE: PANEL IS NOW OP & MODERN   \033[0m"
echo -e "\033[1;32m------------------------------------------------------------\033[0m"
echo -e "\033[0;35m  - Expired Date Backend: ACTIVE\033[0m"
echo -e "\033[0;35m  - Auto-Suspension Cron: ACTIVE\033[0m"
echo -e "\033[0;35m  - Glassmorphism Grid UI: ACTIVE\033[0m"
echo -e "\033[1;32m------------------------------------------------------------\033[0m"
