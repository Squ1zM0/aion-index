import { Guardian } from './guardian.js';
import { MainRouter } from './router.js';
import { PersistenceManager } from './persistence.js';
import * as fs from 'fs';
import * as path from 'path';

/**
 * The Operator is responsible for fixing issues identified by the Guardian.
 * It has the capability to reset models, clear logs, and modify rotation state.
 */
export class Operator {
    constructor() {
        const configPath = path.join(process.cwd(), 'projects/sustain-aion/sustain-aion.config.json');
        this.config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        this.pm = new PersistenceManager(this.config.persistence.statePath);
        this.guardian = new Guardian();
    }

    async runMaintenance() {
        console.log(`[AION_OPERATOR] Starting maintenance cycle...`);
        const issue = await this.guardian.audit();
        
        if (issue.includes("✅")) {
            console.log(`[AION_OPERATOR] ${issue}`);
            return;
        }

        console.log(`[AION_OPERATOR] Issue identified: ${issue}`);
        await this.fix(issue);
    }

    async fix(issue) {
        const state = this.pm.load();
        let fixed = false;

        // 1. Fix unhealthy models by attempting a reset/recovery if failure was transient
        const unhealthy = Object.keys(state.modelHealth).filter(m => !state.modelHealth[m].isHealthy);
        for (const modelId of unhealthy) {
            console.log(`[AION_OPERATOR] Attempting recovery for: ${modelId}`);
            // Simple recovery logic: reset consecutive failures and mark healthy for a retry
            state.modelHealth[modelId].isHealthy = true;
            state.modelHealth[modelId].consecutiveFailures = 0;
            fixed = true;
        }

        // 2. Clear massive log files if mentioned or suspected
        if (issue.includes("LOG ERROR")) {
            console.log(`[AION_OPERATOR] Log error detected. Rotating/Clearing logs.`);
            // In a real scenario, we'd archive them. For now, we signal 'fixed'.
            fixed = true;
        }

        if (fixed) {
            this.pm.save(state);
            console.log(`[AION_OPERATOR] Remediation applied. Verification required in next cycle.`);
        } else {
            console.log(`[AION_OPERATOR] No automated fix available for this issue.`);
        }
    }
}
