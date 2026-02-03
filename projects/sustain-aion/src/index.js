import * as fs from 'fs';
import * as path from 'path';
import { PersistenceManager } from './persistence.js';
import { Classifier } from './classifier.js';
import { Rotator } from './rotation.js';

async function main() {
    const configPath = path.join(process.cwd(), 'projects/sustain-aion/sustain-aion.config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

    const pm = new PersistenceManager(config.persistence.statePath);
    const state = pm.load();
    
    const classifier = new Classifier(config);
    const rotator = new Rotator(config, state);

    const prompt = process.argv[2] || "Hello";
    const contextLength = parseInt(process.argv[3]) || 1000;
    const hasAttachment = process.argv[4] === 'true';

    console.log(`[SUSTAIN-AION] Analyzing request: "${prompt.substring(0, 50)}..."`);
    
    const category = classifier.classify(prompt, contextLength, hasAttachment);
    console.log(`[SUSTAIN-AION] Assigned category: ${category}`);

    const selectedModel = rotator.getNextModel(category);
    console.log(`[SUSTAIN-AION] Selected substrate: ${selectedModel}`);

    state.usageStats.daily.requestsByModel[selectedModel] = (state.usageStats.daily.requestsByModel[selectedModel] || 0) + 1;
    
    pm.save(state);
    console.log(`[SUSTAIN-AION] State persisted.`);
}

main().catch(console.error);
