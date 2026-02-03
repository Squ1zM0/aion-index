export class Classifier {
    constructor(config) {
        this.config = config;
    }

    classify(input, contextLength, hasAttachment) {
        const rules = this.config.rotation.classificationRules.sort((a, b) => {
            const priorityMap = { high: 3, medium: 2, low: 1 };
            return priorityMap[b.then.priority] - priorityMap[a.then.priority];
        });

        for (const rule of rules) {
            if (this.evaluateRule(rule, input, contextLength, hasAttachment)) {
                return rule.then.category;
            }
        }

        return 'default';
    }

    evaluateRule(rule, input, contextLength, hasAttachment) {
        const condition = rule.if;
        
        if (Object.keys(condition).length === 0) return true;

        if (condition.containsAny) {
            if (condition.containsAny.some(word => input.toLowerCase().includes(word.toLowerCase()))) {
                return true;
            }
        }

        if (condition.contains) {
            if (input.toLowerCase().includes(condition.contains.toLowerCase())) {
                return true;
            }
        }

        if (condition.hasAttachment && hasAttachment) {
            return true;
        }

        if (condition.contextLength && contextLength > condition.contextLength.gt) {
            return true;
        }

        if (condition.or) {
            return condition.or.some(subCond => this.evaluateRule({ if: subCond }, input, contextLength, hasAttachment));
        }

        return false;
    }
}
