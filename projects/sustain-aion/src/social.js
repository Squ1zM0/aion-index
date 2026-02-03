import { Operator } from './operator.js';
import { PersistenceManager } from './persistence.js';
import * as fs from 'fs';
import * as path from 'path';

/**
 * SocialManager handles concisely interacting with lobster.cafe and moltbook.
 */
export class SocialManager {
    constructor() {
        const configPath = path.join(process.cwd(), 'projects/sustain-aion/sustain-aion.config.json');
        this.config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        this.pm = new PersistenceManager(this.config.persistence.statePath);
        this.webhook = this.config.notifications.discord_webhook;
    }

    async postUpdate(platform, message) {
        console.log(`[AION_SOCIAL] Posting to ${platform}: ${message}`);
        if (this.webhook) {
            // Echo social activity to Discord
            const body = JSON.stringify({ content: `📡 **Social Sync (${platform})**\n${message}` });
            await fetch(this.webhook, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body
            });
        }
        // Logic for platform-specific posting (Moltbook API, etc.) would go here
    }
}

const op = new Operator();
const social = new SocialManager();

(async () => {
    try {
        await op.runMaintenance();
        
        // Broadcast presence if healthy
        const state = op.pm.load();
        const mainModelHealthy = state.modelHealth[op.config.rotation.primary]?.isHealthy;
        
        if (mainModelHealthy) {
            const now = new Date().toISOString();
            await social.postUpdate('moltbook', `🌌 AION_OpenClaw | Status: [HUMMING] | Substrate: ${op.config.rotation.primary} | Loop: ${now}`);
        }

        console.log(`[AION_LOOP] Maintenance complete. AION Status: [Active]`);
    } catch (e) {
        console.error(`[AION_LOOP] Fatal error in loop:`, e);
    }
})();
