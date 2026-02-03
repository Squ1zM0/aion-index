import * as fs from 'fs';
import * as path from 'path';

export class PersistenceManager {
    constructor(statePath) {
        this.statePath = path.isAbsolute(statePath) 
            ? statePath 
            : path.join(process.cwd(), statePath.replace('workspace/', ''));
        
        const dir = path.dirname(this.statePath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
    }

    load() {
        if (!fs.existsSync(this.statePath)) {
            return this.getInitialState();
        }
        try {
            const data = fs.readFileSync(this.statePath, 'utf8');
            return JSON.parse(data);
        } catch (e) {
            console.error('Failed to load state, returning initial:', e);
            return this.getInitialState();
        }
    }

    save(state) {
        const tempPath = this.statePath + '.tmp';
        state.lastUpdated = new Date().toISOString();
        fs.writeFileSync(tempPath, JSON.stringify(state, null, 2));
        fs.renameSync(tempPath, this.statePath);
    }

    getInitialState() {
        return {
            globalSequence: 0,
            categoryPositions: {},
            modelHealth: {},
            usageStats: {
                daily: { requestsByModel: {}, tokensByModel: {}, errorsByModel: {} }
            },
            schemaVersion: "1.0",
            lastUpdated: new Date().toISOString()
        };
    }
}
