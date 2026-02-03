export interface RotationState {
  globalSequence: number;
  categoryPositions: {
    [category: string]: {
      lastModelId: string;
      sequenceInCategory: number;
      modelsInPool: string[];
    }
  };
  modelHealth: {
    [modelId: string]: {
      lastUsed: string;
      successCount: number;
      failureCount: number;
      avgResponseTime: number;
      lastFailure: string | null;
      consecutiveFailures: number;
      isHealthy: boolean;
    }
  };
  usageStats: {
    [period: string]: {
      requestsByModel: { [modelId: string]: number };
      tokensByModel: { [modelId: string]: number };
      errorsByModel: { [modelId: string]: number };
    }
  };
  schemaVersion: "1.0";
  lastUpdated: string;
}

export interface SustainAionConfig {
  enabled: boolean;
  rotation: {
    mode: string;
    maxRetries: number;
    categories: {
      [key: string]: {
        models: string[];
        rotationStrategy: string;
        weights?: { [modelId: string]: number };
      }
    };
    classificationRules: ClassificationRule[];
  };
  persistence: {
    statePath: string;
  };
}

export interface ClassificationRule {
  name: string;
  if: {
    containsAny?: string[];
    contains?: string;
    hasAttachment?: string;
    contextLength?: { gt: number };
    or?: any[];
  };
  then: {
    category: string;
    priority: string;
    filter?: { minContextWindow: number };
  };
}
