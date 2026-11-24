# Live run through the AI gateway (2026-11-24)

First recorded run of the photo-to-recipe call **through the `ai-gateway` Edge
Function with a signed-in account**, as CAP-02 and CAP-05 ask. Earlier live
cases in [results.md](results.md) went through `RecipeAI` with a personal key.

## Setup

- Local Supabase (`supabase start`, `supabase db reset`), `supabase functions
  serve ai-gateway`; edge runtime 1.74.3, compatible with Deno 2.1.4.
- Synthetic account `capstone-synthetic@example.test`, confirmed through the
  local mail catcher, signed in with a password. No hosted project was touched.
- Provider keys (Gemini, Groq) came from an env file outside the repository
  passed with `--env-file`; they are not in this repository or in the logs.
- Code under test: `dev` at `de9dd09` plus PR #177 (`99e54c7`, server-side check
  of the recipe answer); the model id fix of PR #181 for the last row.
- The prompts are the real app prompts (`recipeSystemPrompt`,
  `recipeFromImagePrompt()`), temperature 0.1.
- The images are **synthetic**, drawn with ImageMagick: a printed recipe page
  ("Palačinke sa sirom"), a blue gradient (not a recipe) and blurred noise
  (unreadable). They are not photos of a real cookbook.

## Results

| Case | Model | Status | Time | Outcome |
| --- | --- | --- | --- | --- |
| Recipe page | `gemini/gemini-flash-lite-latest` (3 runs) | 200 | 1.8–1.9 s | Correct recipe: 4 servings, 5 ingredients (300 g flour, 500 ml milk, 2 eggs, 250 g cheese, 1 pinch of salt), 3 steps |
| Recipe page | `groq/qwen/qwen3.8-27b` | 200 | 1.6 s | Same recipe, 5 ingredients, 3 steps |
| Not a recipe | `gemini/gemini-flash-lite-latest` | 200 | 1.0 s | `{"error": "not_a_recipe"}` |
| Unreadable | `gemini/gemini-flash-lite-latest` | 200 | 8.9 s | `{"error": "not_a_recipe"}` |
| Recipe page | `gemini/gemini-flash-latest` (4 runs) | 502 `provider_error` | 1–3.5 s | Provider answered 503 "high demand" (checked with a direct call); the gateway returned a typed error |
| Recipe page | `gemini/gemini-pro-latest` | 429 `provider_rate_limited` | 0.3 s | Typed rate-limit error |
| Recipe page | `groq/qwen/qwen3.6-27b` | 503 `model_unavailable` | 0.1–0.2 s | **Finding:** Groq no longer serves this id; fixed in PR #181 |

Gateway checks in the same run:

| Check | Result |
| --- | --- |
| No token, or an invalid token | 401 |
| Extra field in the body (`uid`) | 400 `bad_request` |
| Model that is not on the allowlist | 400 `bad_request` |
| Image that is not a valid JPEG/PNG | 400 `bad_request` |
| Model list (`GET`) | Only models whose key is configured |

## What this shows and what it does not

- A signed-in photo request reaches a provider, returns structured recipe JSON
  and passes the server check. This also shows that image decoding (PR #175)
  works on the edge runtime.
- Errors from the provider (503, 429, retired model) come back as typed gateway
  errors, not as raw provider text.
- **Not shown:** a real photograph; the full app flow (review, confirm, plan,
  shopping list) through the gateway; EV-01 to EV-10 rerun; a hosted run.
- **Not verified:** the `413` response for a body over 1.5 MB. The gateway code
  returns it from the `Content-Length` header and a unit test covers it, but
  against the local stack the request hung until the client timeout (30 s), even
  though bodies under the limit were answered in under 0.1 s. The cause was not
  identified (local relay or runtime behavior is likely; no code defect was
  proven). Check on a hosted environment before claiming it.
- `groq/llama-3.3-70b-versatile` is missing from the Groq model list of the key
  used; it was not tested.
