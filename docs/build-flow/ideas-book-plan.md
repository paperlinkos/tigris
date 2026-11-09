# Ideas book: plan (stage 1 of build-flow)

Status: approved 2 Nov 2026 (stage 1, six statuses, own area). Design next.

## Who and why
You, a writer and builder. Ideas arrive at odd moments (story, app, sermon, feature). You want to catch them fast in Tigris, and later hand the good ones to an agent (Codex, Claude Code, or another) to act on.

## The idea in one line
An **Ideas book** is a special notebook in Tigris. Each idea is a quick note with a status. Any idea can become a **brief** that an agent can pick up.

## Must-haves (version 1)
1. **Ideas book** appears in the sidebar and on the phone home, next to Notes. Opening it shows a list of ideas, newest first.
2. **Quick capture**: one tap or `Mod+Alt+I`, type a title, optionally a line or two. It is an ordinary Tigris note underneath, so it works offline, syncs, backs up and can hold blocks, nested pages and links, like everything else.
3. **Status** on each idea: `Spark` (new), `Exploring`, `Ready`, `Handed off`, `Done`, `Parked`. Filter by status.
4. **Make a brief** on an idea (menu or button): turns the idea into a Markdown brief an agent can use, with Goal, Context, What done looks like, and any notes. You edit it before sending.
5. **Hand off**, three ways, all available everywhere that makes sense:
   - **Copy** the brief, plus a ready-to-paste prompt for Codex or Claude Code.
   - **Save as file** (`.md`) to a folder you choose.
   - **Run** (macOS desktop app only): save the brief into a project folder and open the command in Terminal. Needs your OK each time.
6. The idea records where it went (`Handed off to Codex, 2 Nov`) and you can mark it Done by hand.

## Not in version 1
- Tigris launching agents on phone or web (not possible: they can't reach your Mac's tools).
- Agents writing results back into Tigris.
- AI that ranks or merges ideas.

## How "connect to agents" works, in stages
| Stage | What it adds | Works on |
|---|---|---|
| 1 (this plan) | Brief + copy / save file / run in Terminal | Phone, web, Mac |
| 2 | A small **Tigris MCP server** on your Mac so Claude Code and Codex can read your Ideas book directly ("pick up my Ready ideas") | Mac |
| 3 | Agent writes a summary back as a note under the idea | Mac, syncs everywhere |

Stage 1 is small and useful alone, and stage 2 builds on its brief format, so nothing is thrown away.

## Decisions I need from you
1. **Is stage 1 enough to start?** (Recommended: yes.)
2. **Statuses**: are the six above right, or fewer? (Recommended: keep them.)
3. **Where does "Run" send briefs by default?** One folder you pick once, such as `~/.claude/handoffs/`, or a project folder per idea?
4. **Ideas book location**: its own top-level area (recommended), or just a tag on normal notes?

## How it fits what exists
- Ideas are `Note`s with a `kind: idea`, `ideaStatus` and `handedOffTo` field, so storage, sync, backup and Drive need no new tables.
- Sidebar and phone home get one new entry. Editor unchanged.
- Brief builder is plain Dart, fully unit-testable. Copy and save use platform share/clipboard. "Run" is macOS only and hidden elsewhere.
- Existing notes are untouched: missing fields mean "not an idea".

## Next stages after approval
Design: add Ideas list, capture, brief sheet and hand-off menu to the design system and prototype for your approval. Then code goes to Codex with a written brief, and I review it.

## Revision 2 (2 Nov 2026, from you): Ideas is its own workspace
This replaces the flat list and the "special notebook" idea above.

- A **workspace switch at the top** of the app (`Notes | Ideas`). Ideas is a separate environment with its own tree of notes and sub-notes, its own search, and the same editor, drag lines and nesting as Notes. Nothing from Ideas shows in Notes, and the other way round.
- Under the hood: every note gets a `workspace` field (`notes` by default, `ideas`). Storage, sync, backup and Notion import stay as they are. Each workspace filters the same notes by this field. Existing notes need no change.
- Status (Spark, Exploring, Ready, Handed off, Done, Parked) stays, but only on top-level ideas, shown as a small label in the top bar.
- **Brainstorm chat (later, stage 2):** a side panel where an AI helps refine the open idea by chatting. The design reserves the space now. It needs the AI Cloud Function, so it is not in version 1.
- **Ship to agent:** from any idea, one button. The brief is built from the idea and all its sub-notes, with the same copy / save / run choices as before.

Stages now: 1 = the Ideas workspace plus Ship to agent. 2 = Brainstorm chat. 3 = Tigris MCP server so agents read Ready ideas directly, and write results back.

## Revision 3 (2 Nov 2026): Brainstorm provider and privacy

- Brainstorm is a session-only chat panel for an open idea. It sends that idea and its nested pages as context; chat messages are not added to notes, sync, backups or briefs.
- The default is OpenRouter's `openrouter/free` model router. The user supplies their own API key, so free-provider limits apply to their account.
- Settings also offer Gemini and a custom OpenAI-compatible chat-completions endpoint/model. This keeps the feature usable with a provider of the user's choosing where it supports that standard.
- API keys and their local provider settings are held only in OS-backed secure storage on the current device, never in the Tigris note store.
