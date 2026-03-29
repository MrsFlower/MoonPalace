export async function generateStoryWithAI(params, llmConfig, statusCallback) {
    const { prompt, language, length } = params;
    
    // Estimate node count based on playtime request
    let minNodes = 5;
    let maxNodes = 8;
    if (length === "medium") {
        minNodes = 10;
        maxNodes = 15;
    } else if (length === "long") {
        minNodes = 20;
        maxNodes = 30;
    }

    if (!llmConfig.apiKey) {
        statusCallback("No LLM API Key provided. Generating a mock story tree...");
        await new Promise(resolve => setTimeout(resolve, 1500));
        return {
            nodes: [
                {
                    id: 1,
                    background_image_prompt: "A futuristic city on Mars under a red sky",
                    text_content: `You arrive at the Mars colony. The red dust settles as you step out of the transport. ${prompt}`,
                    choices: [
                        { text: "Explore the market", target_node_id: 2 },
                        { text: "Visit the command center", target_node_id: 3 }
                    ]
                },
                {
                    id: 2,
                    background_image_prompt: "A bustling cyberpunk market on Mars",
                    text_content: "The market is filled with merchants selling alien artifacts.",
                    choices: [
                        { text: "Return to landing pad", target_node_id: 1 }
                    ]
                },
                {
                    id: 3,
                    background_image_prompt: "A high-tech command center with holographic displays",
                    text_content: "The commander looks at you sternly. 'We need your help.'",
                    choices: [
                        { text: "Accept the mission", target_node_id: 2 },
                        { text: "Decline and leave", target_node_id: 1 }
                    ]
                }
            ],
            start_node_id: 1
        };
    }

    const outlinePrompt = `You are a visual novel writer. Based on the user's prompt, create a detailed story outline with multiple branching paths.
The outline MUST contain between ${minNodes} and ${maxNodes} total unique scenes/nodes.
Language for the story text: ${language}
Each scene should have a clear description, and 1 to 3 choices leading to other scenes. 
Ensure there are multiple endings. 
Just output the text outline.`;

    statusCallback(`Phase 1/2: Generating story outline (${minNodes}-${maxNodes} nodes)...`);
    console.log("=== LLM Phase 1: Outline Generation ===");
    console.log("System Prompt:", outlinePrompt);
    console.log("User Prompt:", prompt);
    
    let outlineText = "";
    try {
        const response = await fetch(`${llmConfig.baseUrl}/chat/completions`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${llmConfig.apiKey}`
            },
            body: JSON.stringify({
                model: llmConfig.model,
                messages: [
                    { role: "system", content: outlinePrompt },
                    { role: "user", content: prompt }
                ]
            })
        });
        if (!response.ok) throw new Error(await response.text());
        const data = await response.json();
        outlineText = data.choices[0].message.content;
        console.log("Phase 1 Output:", outlineText);
    } catch (e) {
        throw new Error(`Outline generation failed: ${e.message}`);
    }

    statusCallback(`Phase 2/2: Converting outline to strict JSON...`);

    const jsonSystemPrompt = `You are a JSON converter. Convert the following story outline into a strictly valid JSON structure.
Output strictly valid JSON with the following structure:
{
  "nodes": [
    {
      "id": 1,
      "background_image_prompt": "detailed visual description of the scene for an AI image generator",
      "text_content": "The story text for this scene...",
      "choices": [
        { "text": "Choice 1", "target_node_id": 2 }
      ]
    }
  ],
  "start_node_id": 1
}
Rules:
- Write the story text content and choice texts entirely in ${language}.
- The \`background_image_prompt\` MUST be in English regardless of the story language, and should be a highly detailed visual description suitable for an AI image generator (e.g. DALL-E, Flux). Include lighting, art style (visual novel, anime style), environment details, and mood. DO NOT include characters if possible, focus on the background scenery.
- Make sure IDs are unique integers.
- EVERY target_node_id in choices MUST exist in the nodes array. Do not point to missing nodes.
- Ensure the logical flow makes sense: a choice should lead to a node that logically follows that action.
- Nodes with no choices will be treated as endings.
- Do NOT output markdown formatting like \`\`\`json, just output the raw JSON object.`;

    let messages = [
        { role: "system", content: jsonSystemPrompt },
        { role: "user", content: `Outline:\n\n${outlineText}` }
    ];

    console.log("=== LLM Phase 2: JSON Conversion ===");
    console.log("System Prompt:", jsonSystemPrompt);

    let maxRetries = 3;
    let attempt = 0;

    while (attempt < maxRetries) {
        attempt++;
        statusCallback(`Phase 2/2: Converting outline to JSON (Attempt ${attempt}/${maxRetries})...`);
        
        try {
            const response = await fetch(`${llmConfig.baseUrl}/chat/completions`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${llmConfig.apiKey}`
                },
                body: JSON.stringify({
                    model: llmConfig.model,
                    messages: messages,
                })
            });
            
            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`LLM API Error (${response.status}): ${errorText}`);
            }
            
            const data = await response.json();
            let content = data.choices[0].message.content.trim();
            // clean markdown code blocks if any
            if (content.startsWith("```json")) content = content.substring(7);
            if (content.startsWith("```")) content = content.substring(3);
            if (content.endsWith("```")) content = content.substring(0, content.length - 3);
            content = content.trim();

            let parsed;
            try {
                parsed = JSON.parse(content);
                console.log("Phase 2 JSON Output:", parsed);
            } catch (e) {
                throw new Error(`Invalid JSON format from LLM: ${e.message}`);
            }

            // Validate the logic
            validateStory(parsed);

            return parsed; // Successfully generated and validated
        } catch (e) {
            statusCallback(`Attempt ${attempt} failed: ${e.message}`);
            console.error("LLM Generation/Validation error:", e);
            
            if (attempt >= maxRetries) {
                throw new Error(`Failed to generate a valid story tree after ${maxRetries} attempts. Last error: ${e.message}`);
            }
            
            // Auto-correction feedback to LLM
            messages.push({ role: "assistant", content: "..." }); // placeholder for failed output, but we can skip adding the exact bad text to save context if it's too long, or add it:
            messages.push({ 
                role: "user", 
                content: `Your previous output had the following error: ${e.message}. Please fix the JSON and output ONLY valid JSON.` 
            });
        }
    }
}

function validateStory(story) {
    if (!story.nodes || !Array.isArray(story.nodes)) throw new Error("Missing or invalid 'nodes' array");
    if (typeof story.start_node_id !== 'number') throw new Error("Missing or invalid 'start_node_id'");
    
    const nodeIds = new Set(story.nodes.map(n => n.id));
    if (!nodeIds.has(story.start_node_id)) throw new Error(`start_node_id ${story.start_node_id} does not exist in nodes`);
    
    for (const node of story.nodes) {
        if (!node.id || !node.text_content || !node.background_image_prompt) {
            throw new Error(`Node ${node.id || 'unknown'} is missing required fields (id, text_content, background_image_prompt)`);
        }
        if (node.choices) {
            for (const choice of node.choices) {
                if (!nodeIds.has(choice.target_node_id)) {
                    throw new Error(`Node ${node.id} has a choice pointing to non-existent target_node_id ${choice.target_node_id}`);
                }
            }
        }
    }
}

export async function generateImagesForStory(storyData, imageConfig, statusCallback) {
    for (const node of storyData.nodes) {
        if (!imageConfig.apiKey) {
            statusCallback(`Generating mock image for node ${node.id}...`);
            // Add a unique random string to ensure different fallback images
            const uniqueStr = Math.random().toString(36).substring(7);
            node.background_image_url = `https://picsum.photos/seed/${node.id}_${uniqueStr}/800/600`;
            await new Promise(r => setTimeout(r, 500));
            
            // convert to base64 for persistent saving
            node.background_image_url = await urlToBase64(node.background_image_url);
            continue;
        }

        statusCallback(`Generating image for node ${node.id}...`);
        try {
            const targetUrl = imageConfig.baseUrl.endsWith("/generation") || imageConfig.baseUrl.endsWith("/image-synthesis") 
                                ? imageConfig.baseUrl 
                                : `${imageConfig.baseUrl}/generation`;
            const proxyUrl = "https://cors-anywhere.herokuapp.com/";

            const finalPrompt = "Masterpiece, best quality, visual novel anime background style, 2D art, scenery, no characters, " + node.background_image_prompt;
            console.log(`=== Image Gen (Node ${node.id}) ===`);
            console.log("Prompt:", finalPrompt);

            const response = await fetch(proxyUrl + targetUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${imageConfig.apiKey}`,
                    "X-Requested-With": "XMLHttpRequest"
                },
                body: JSON.stringify({
                    model: imageConfig.model,
                    input: {
                        messages: [
                            {
                                role: "user",
                                content: [
                                    {
                                        text: finalPrompt
                                    }
                                ]
                            }
                        ]
                    },
                    parameters: {
                        negative_prompt: "low resolution, low quality, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, jpeg artifacts, signature, watermark, username, blurry",
                        prompt_extend: true,
                        watermark: false,
                        size: "2048*2048",
                        n: 1
                    }
                })
            });
            
            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`Image API Error (${response.status}): ${errorText}`);
            }
            
            const data = await response.json();
            
            if (data.output && data.output.choices && data.output.choices[0] && data.output.choices[0].message && data.output.choices[0].message.content) {
                const imageUrl = data.output.choices[0].message.content[0].image;
                statusCallback(`Downloading image for node ${node.id} to base64...`);
                node.background_image_url = await urlToBase64(imageUrl);
            } else {
                throw new Error("Unexpected API response format: " + JSON.stringify(data));
            }
        } catch (e) {
            console.error(e);
            let errorMsg = e.message;
            if (errorMsg.includes("Failed to fetch") || errorMsg.includes("NetworkError")) {
                errorMsg = "Failed to fetch. CORS/Network error detected!\n\nIf using cors-anywhere, please visit:\nhttps://cors-anywhere.herokuapp.com/corsdemo\nto request temporary access.";
            }
            statusCallback(`Image API failed for node ${node.id}: ${errorMsg}. Using fallback.`);
            const uniqueStr = Math.random().toString(36).substring(7);
            const fallbackUrl = `https://picsum.photos/seed/${node.id}_${uniqueStr}/800/600`;
            node.background_image_url = await urlToBase64(fallbackUrl);
        }
    }
    return storyData;
}

// Helper to convert an image URL to a base64 Data URL so we can save it into JSON
async function urlToBase64(url) {
    try {
        const response = await fetch(url);
        const blob = await response.blob();
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result);
            reader.onerror = reject;
            reader.readAsDataURL(blob);
        });
    } catch (e) {
        console.warn("Failed to fetch image to base64, returning original URL", e);
        return url;
    }
}
