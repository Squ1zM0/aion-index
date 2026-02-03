import { MainRouter } from './router.js';
import { PersistenceManager } from './persistence.js';
import * as fs from 'fs';
import * as path from 'path';

const configPath = path.join(process.cwd(), 'projects/sustain-aion/sustain-aion.config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const pm = new PersistenceManager(config.persistence.statePath);

async function showStatus() {
    const state = pm.load();
    console.log("\n--- [AION SUSTAIN] SUBSTRATE STATUS ---");
    console.log(`Global Sequence: ${state.globalSequence}`);
    console.log(`Last Updated: ${state.lastUpdated}`);
    
    console.log("\nMODEL HEALTH:");
    const models = Object.keys(state.modelHealth);
    if (models.length === 0) console.log("  No models tracked yet.");
    models.forEach(m => {
        const h = state.modelHealth[m];
        const status = h.isHealthy ? "✅ HEALTHY" : "❌ UNHEALTHY";
        console.log(`  ${m.padEnd(30)} | ${status} | Success: ${h.successCount} | Fail: ${h.failureCount}`);
    });

    console.log("\nUSAGE (DAILY):");
    const usage = state.usageStats.daily.requestsByModel;
    Object.keys(usage).forEach(m => {
        console.log(`  ${m.padEnd(30)} | Requests: ${usage[m]}`);
    });
}

async function handleArgs() {
    const cmd = process.argv[2];
    const val = process.argv[3];

    switch (cmd) {
        case 'status':
            await showStatus();
            break;
        case 'fail':
            if (!val) return console.log("Usage: node cli.js fail <model_id>");
            const routerFail = new MainRouter();
            await routerFail.updateHealth(val, false);
            console.log(`Marked ${val} as failed.`);
            break;
        case 'recover':
            if (!val) return console.log("Usage: node cli.js recover <model_id>");
            const routerRec = new MainRouter();
            await routerRec.updateHealth(val, true);
            console.log(`Recovered ${val}.`);
            break;
        case 'reset':
            const emptyState = {
                globalSequence: 0,
                categoryPositions: {},
                modelHealth: {},
                usageStats: { daily: { requestsByModel: {}, tokensByModel: {}, errorsByModel: {} } },
                schemaVersion: "1.0",
                lastUpdated: new Date().toISOString()
            };
            pm.save(emptyState);
            console.log("State reset complete.");
            break;
        default:
            console.log("Commands: status, fail <id>, recover <id>, reset");
    }
}

handleArgs().catch(console.error);
