import { Operator } from './operator.js';

async function main() {
    const operator = new Operator();
    await operator.runMaintenance();
}

main().catch(console.error);
