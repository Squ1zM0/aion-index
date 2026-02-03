import { Guardian } from './guardian.js';

async function main() {
    const guardian = new Guardian();
    const result = await guardian.audit();
    console.log(`[AION_GUARDIAN] ${result}`);
}

main().catch(console.error);
