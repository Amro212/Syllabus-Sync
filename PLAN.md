Work Plan:
1. Update shared schema/types: remove courseId, make courseCode required everywhere (TS types, JSON schema, validation). Introduce helper to detect courseCode.
2. Adjust server pipeline (index.ts, validation, prompts, tests) to use courseCode with OpenAI parsing.
3. Update iOS client types/models and any references/tests to align with courseCode-only responses.
