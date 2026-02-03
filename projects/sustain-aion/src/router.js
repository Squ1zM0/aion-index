import * as fs from 'fs';
import * as path from 'path';
import { PersistenceManager } from './persistence.js';
import { Classifier } from './classifier.js';
import { Rotator } from './rotation.js';

export class MainRouter {
    constructor() {
        const configPath = path.join(process.cwd(), 'projects/sustain-aion/sustain-aion.config.json');
        this.config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        this.pm = new PersistenceManager(this.config.persistence.statePath);
        this.classifier = new Classifier(this.config);
    }

    async resolveModel(prompt, contextLength = 0, hasAttachment = false) {
        const state = this.pm.load();
        const rotator = new Rotator(this.config, state);
        
        const category = this.classifier.classify(prompt, contextLength, hasAttachment);
        const modelId = rotator.getNextModel(category);
        
        // Update stats
        state.usageStats.daily.requestsByModel[modelId] = (state.usageStats.daily.requestsByModel[modelId] || 0) + 1;
        this.pm.save(state);
        
        return modelId;
    }

    async updateHealth(modelId, success, responseTime) {
        const state = this.pm.load();
        const rotator = new Rotator(this.config, state);
        rotator.updateHealth(modelId, success, responseTime);
        this.pm.save(state);
    }
}
