export class Rotator {
    constructor(config, state) {
        this.config = config;
        this.state = state;
    }

    getNextModel(category) {
        const pool = this.config.rotation.categories[category] || this.config.rotation.categories['default'];
        const healthyModels = pool.models.filter(m => {
            const health = this.state.modelHealth[m];
            return !health || health.isHealthy;
        });

        if (healthyModels.length === 0) {
            return this.config.rotation.categories['local_fallback'].models[0];
        }

        const catPos = this.state.categoryPositions[category] || { 
            lastModelId: '', 
            sequenceInCategory: 0,
            modelsInPool: healthyModels 
        };

        const nextIndex = catPos.sequenceInCategory % healthyModels.length;
        const selectedModel = healthyModels[nextIndex];

        this.state.globalSequence++;
        this.state.categoryPositions[category] = {
            lastModelId: selectedModel,
            sequenceInCategory: catPos.sequenceInCategory + 1,
            modelsInPool: healthyModels
        };

        return selectedModel;
    }

    updateHealth(modelId, success, responseTime) {
        if (!this.state.modelHealth[modelId]) {
            this.state.modelHealth[modelId] = {
                lastUsed: new Date().toISOString(),
                successCount: 0,
                failureCount: 0,
                avgResponseTime: 0,
                lastFailure: null,
                consecutiveFailures: 0,
                isHealthy: true
            };
        }

        const health = this.state.modelHealth[modelId];
        health.lastUsed = new Date().toISOString();

        if (success) {
            health.successCount++;
            health.consecutiveFailures = 0;
            health.isHealthy = true;
            if (responseTime) {
                health.avgResponseTime = (health.avgResponseTime * 0.9) + (responseTime * 0.1);
            }
        } else {
            health.failureCount++;
            health.consecutiveFailures++;
            health.lastFailure = new Date().toISOString();
            if (health.consecutiveFailures >= 3) {
                health.isHealthy = false;
            }
        }
    }
}
