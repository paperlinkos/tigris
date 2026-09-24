const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

/**
 * Strips markdown code blocks if the LLM wrapped JSON in ```json ... ```
 */
function cleanJsonOutput(raw) {
  let cleaned = (raw || "").trim();
  if (cleaned.startsWith("```json")) {
    cleaned = cleaned.replace(/^```json\s*/, "");
  } else if (cleaned.startsWith("```")) {
    cleaned = cleaned.replace(/^```\s*/, "");
  }
  if (cleaned.endsWith("```")) {
    cleaned = cleaned.replace(/```$/, "").trim();
  }
  return cleaned;
}

/**
 * analyzeNote Cloud Function
 *
 * Requirements:
 * - Flutter -> Cloud Function -> Gemini API -> Cloud Function -> Flutter
 * - Gemini API key is securely stored in backend secrets / process.env.
 * - Authenticated via Firebase ID token in Authorization: Bearer <idToken> header.
 * - Accepts JSON: { "noteId": "...", "content": "..." }
 * - Returns STRICT JSON:
 *   {
 *     "title": "",
 *     "date": "",
 *     "service": "",
 *     "speaker": "",
 *     "topics": [],
 *     "keyPoints": [],
 *     "unknownTerms": [
 *       { "term": "...", "reason": "..." }
 *     ]
 *   }
 */
exports.analyzeNote = onRequest(
  {
    cors: true,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    // Only allow POST requests
    if (req.method !== "POST") {
      res.status(405).json({
        error: "Method Not Allowed",
        message: "Only POST requests are supported.",
      });
      return;
    }

    // 1. Verify Authentication
    const authHeader = req.headers.authorization || "";
    let userId = null;

    if (authHeader.startsWith("Bearer ")) {
      const idToken = authHeader.split("Bearer ")[1].trim();
      try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        userId = decodedToken.uid;
      } catch (authErr) {
        console.error("Token verification failed:", authErr.message);
        res.status(401).json({
          error: "Unauthorized",
          message: "Invalid or expired Firebase authentication token.",
        });
        return;
      }
    } else {
      res.status(401).json({
        error: "Unauthorized",
        message: "Missing Authorization header with Firebase ID token.",
      });
      return;
    }

    // 2. Validate Input
    const body = req.body || {};
    const noteId = body.noteId;
    const content = body.content;

    if (!noteId || typeof noteId !== "string") {
      res.status(400).json({
        error: "Bad Request",
        message: "Missing or invalid 'noteId'.",
      });
      return;
    }

    if (!content || typeof content !== "string" || content.trim().length === 0) {
      res.status(400).json({
        error: "Bad Request",
        message: "Note content cannot be empty.",
      });
      return;
    }

    // 3. Resolve Gemini API Key from secrets or environment
    const apiKey =
      process.env.GEMINI_API_KEY ||
      (geminiApiKey && typeof geminiApiKey.value === "function"
        ? geminiApiKey.value()
        : null);

    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured.");
      res.status(500).json({
        error: "Internal Server Error",
        message:
          "Gemini API key is not configured on the server. Please set the GEMINI_API_KEY secret.",
      });
      return;
    }

    // 4. Construct Gemini Prompt
    const systemPrompt = `You are an expert notes analysis assistant.
Your task is to analyze note content and return STRICT JSON with the following schema:
{
  "title": "A short descriptive title if mentioned or evident in the note, otherwise empty string",
  "date": "The date mentioned in the note if any, otherwise empty string",
  "service": "The church or meeting service type (e.g. Sunday Service, Midweek Service) if mentioned, otherwise empty string",
  "speaker": "The person or speaker who gave the message/talk if mentioned, otherwise empty string",
  "topics": ["list", "of", "main", "themes", "or", "topics"],
  "keyPoints": ["concise", "actionable", "or", "core", "takeaways", "from", "the", "note"],
  "unknownTerms": [
    {
      "term": "Term or abbreviation whose meaning is not defined or clear in the note",
      "reason": "Clear explanation of why this term is ambiguous or undefined in the note"
    }
  ]
}

STRICT INSTRUCTIONS:
1. Do not return conversational text, greetings, markdown formatting, or explanations.
2. Return ONLY the JSON object.
3. If information (such as title, date, service, speaker) is not present in the note, return an empty string "" or empty array [].
4. UNKNOWN TERMS: Identify terms or abbreviations that appear potentially meaningful (such as unexplained acronyms, abbreviations like H.E.Z.P., specialized references, or undefined names) whose meaning cannot confidently be determined from the note itself.
5. CRITICAL: Do NOT attempt to guess, invent, or hallucinate the meaning of an unknown term or abbreviation.
6. If all terms in the note are common knowledge or explicitly explained, return an empty array for unknownTerms.`;

    const userPrompt = `Note Content:\n---\n${content}\n---`;

    // 5. Call Gemini API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

    const requestBody = {
      contents: [
        {
          role: "user",
          parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }],
        },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.1,
      },
    };

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 45000);

      const response = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Gemini API error:", response.status, errorText);
        res.status(502).json({
          error: "Gemini API Error",
          message: `Gemini API returned status ${response.status}.`,
        });
        return;
      }

      const geminiData = await response.json();
      const rawText =
        geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || "";

      if (!rawText || rawText.trim().length === 0) {
        res.status(502).json({
          error: "Empty AI Response",
          message: "Gemini returned an empty response.",
        });
        return;
      }

      // 6. Parse and Validate JSON Structure
      const cleanedJson = cleanJsonOutput(rawText);
      let parsed;
      try {
        parsed = JSON.parse(cleanedJson);
      } catch (parseErr) {
        console.error("Failed to parse Gemini JSON:", rawText);
        res.status(502).json({
          error: "Invalid JSON from AI",
          message: "Gemini did not return valid JSON.",
          raw: rawText,
        });
        return;
      }

      // Normalize output schema
      const normalizedResult = {
        title: typeof parsed.title === "string" ? parsed.title : "",
        date: typeof parsed.date === "string" ? parsed.date : "",
        service: typeof parsed.service === "string" ? parsed.service : "",
        speaker: typeof parsed.speaker === "string" ? parsed.speaker : "",
        topics: Array.isArray(parsed.topics)
          ? parsed.topics.map((t) => String(t).trim()).filter(Boolean)
          : [],
        keyPoints: Array.isArray(parsed.keyPoints)
          ? parsed.keyPoints.map((k) => String(k).trim()).filter(Boolean)
          : [],
        unknownTerms: Array.isArray(parsed.unknownTerms)
          ? parsed.unknownTerms
              .map((u) => {
                if (typeof u === "string") {
                  return {
                    term: u,
                    reason:
                      "The term appears meaningful but its definition cannot be determined confidently from the note.",
                  };
                }
                return {
                  term: typeof u.term === "string" ? u.term : "",
                  reason:
                    typeof u.reason === "string"
                      ? u.reason
                      : "The abbreviation appears meaningful but its definition cannot be determined confidently from the note.",
                };
              })
              .filter((u) => u.term.length > 0)
          : [],
      };

      res.status(200).json(normalizedResult);
    } catch (err) {
      if (err.name === "AbortError") {
        console.error("Gemini API call timed out.");
        res.status(504).json({
          error: "Timeout",
          message: "Request to Gemini API timed out after 45 seconds.",
        });
        return;
      }

      console.error("Unexpected error in analyzeNote:", err);
      res.status(500).json({
        error: "Internal Server Error",
        message: err.message || "An unexpected error occurred.",
      });
    }
  }
);
