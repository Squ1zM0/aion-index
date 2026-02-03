import { MainRouter } from '../src/router.js';

async function test() {
    const router = new MainRouter();
    
    console.log("--- Testing Substrate Selection ---");
    
    const tests = [
        { name: "Default", prompt: "Hello world", context: 1000, img: false },
        { name: "Reasoning", prompt: "Think through this problem step by step", context: 1000, img: false },
        { name: "Code", prompt: "Write a python script", context: 1000, img: false },
        { name: "Vision", prompt: "Describe this image", context: 1000, img: true },
        { name: "Long Context", prompt: "Analyze this giant file", context: 60000, img: false }
    ];

    for (const t of tests) {
        const model = await router.resolveModel(t.prompt, t.context, t.img);
        console.log(`[TEST: ${t.name}] Input: "${t.prompt}" -> Category: ${router.classifier.classify(t.prompt, t.context, t.img)} -> Substrate: ${model}`);
    }

    console.log("\n--- Testing Health Failover ---");
    const modelToFail = "ollama/kimi-k2.5:cloud";
    console.log(`Failing ${modelToFail}...`);
    
    for (let i = 0; i < 3; i++) {
        await router.updateHealth(modelToFail, false);
    }

    const retryModel = await router.resolveModel("Hello again", 1000, false);
    console.log(`[POST-FAILURE] Substrate selected: ${retryModel} (Should not be ${modelToFail})`);

    console.log("\n--- Testing Recovery ---");
    console.log(`Recovering ${modelToFail}...`);
    await router.updateHealth(modelToFail, true);
    
    const recoveredModel = await router.resolveModel("Hello recovered", 1000, false);
    console.log(`[POST-RECOVERY] Substrate selected: ${recoveredModel}`);
}

test().catch(console.error);
