import { MainRouter } from './router.js';
import { PersistenceManager } from './persistence.js';
import * as fs from 'fs';
import * as path from 'path';

export class Guardian {
    constructor() {
        const configPath = path.join(process.cwd(), 'projects/sustain-aion/sustain-aion.config.json');
        this.config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        this.pm = new PersistenceManager(this.config.persistence.statePath);
    }

    async audit() {
        const state = this.pm.load();
        const unhealthy = Object.keys(state.modelHealth).filter(m => !state.modelHealth[m].isHealthy);
        
        let report = "";
        if (unhealthy.length > 0) {
            report = `⚠️ ALERT: Unhealthy substrates detected: ${unhealthy.join(', ')}.`;
        }

        // Check for recent log errors (last 10 lines of most recent log)
        const logDir = path.join(process.cwd(), 'projects/sustain-aion/.sustain-aion/logs/');
        if (fs.existsSync(logDir)) {
            const logs = fs.readdirSync(logDir).sort().reverse();
            if (logs.length > 0) {
                const recentLog = fs.readFileSync(path.join(logDir, logs[0]), 'utf8');
                if (recentLog.includes('error') || recentLog.includes('fail')) {
                    report += `\n📝 RECENT LOG ERROR detected in ${logs[0]}.`;
                }
            }
        }

        return report || "✅ System integrity verified. No issues detected.";
    }

    async getHelpContext() {
        const state = this.pm.load();
        return {
            status: "AION_OPERATIONAL",
            health: state.modelHealth,
            usage: state.usageStats.daily.requestsByModel,
            timestamp: new Date().toISOString()
        };
    }
}
