export async function loadConfig() {
    let config = {
        llm: { baseUrl: "https://api.moonshot.cn/v1", model: "moonshot-v1-8k", apiKey: "" },
        image: { baseUrl: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis", model: "qwen-image-2.0-pro", apiKey: "" }
    };
    
    try {
        const response = await fetch('config.json');
        if (response.ok) {
            const fileConfig = await response.json();
            config = { ...config, ...fileConfig };
        }
    } catch (e) {
        console.warn("No local config.json found or could not be loaded. Falling back to defaults.");
    }

    // Override with localStorage if they exist and are non-empty
    const localLLM = localStorage.getItem('llmConfig');
    const localImage = localStorage.getItem('imageConfig');
    
    if (localLLM) {
        try { config.llm = { ...config.llm, ...JSON.parse(localLLM) }; } catch(e){}
    }
    if (localImage) {
        try { config.image = { ...config.image, ...JSON.parse(localImage) }; } catch(e){}
    }

    return config;
}

export function saveConfig(llmConfig, imageConfig) {
    localStorage.setItem('llmConfig', JSON.stringify(llmConfig));
    localStorage.setItem('imageConfig', JSON.stringify(imageConfig));
}
