AI Notes App --- Antigravity Build Roadmap

Project Goal

Build a minimalist personal notes and active-learning app around this
loop:

WRITE → ORGANIZE → AI UNDERSTANDS → REVIEW → REMEMBER

The product is inspired by useful parts of Notion, especially nested
pages/notes, but its purpose is different:

Notes should not only store knowledge. They should help the user
remember it.

The app should feel calm, editorial, minimal, and useful every day.

MASTER AUTONOMOUS BUILD INSTRUCTION

Give this instruction to Antigravity before allowing it to work through
the phases.

AUTONOMOUS BUILD MODE

You are working on a Flutter application for a personal note-taking and active-learning product.

The user wants the application built phase-by-phase, but they do NOT want to be interrupted after every phase asking them to inspect the UI, approve the next step, or manually tell you to continue.

Your job is to execute the approved roadmap continuously.

Follow the phase order exactly.

For every phase:

1. Read the current codebase before changing anything.
2. Understand the architecture already implemented.
3. Preserve working functionality from previous phases.
4. Implement the current phase completely.
5. Run the appropriate automated checks.
6. Fix compilation errors, analyzer errors, test failures, and obvious layout/overflow issues yourself.
7. Do not stop merely because something requires a visual review.
8. Record visual-review items as deferred review items and continue.
9. Continue automatically to the next phase once the current phase passes its automated checks.

DO NOT ask the user:

- Would you like me to continue?
- Should I proceed?
- Can you review this first?
- Please inspect the UI before I continue.
- Do you approve this implementation?

The user will review the completed product later.

AUTOMATED QUALITY CONTROL

After each phase:

- run flutter analyze
- run flutter test
- run flutter build web when appropriate
- run any available project-specific tests
- inspect for obvious mobile layout problems
- fix issues automatically
- repeat the checks after fixes

If a test fails:
1. diagnose it
2. fix it
3. rerun the test
4. continue

If flutter analyze reports an issue:
1. diagnose it
2. fix it
3. rerun flutter analyze
4. continue

If a build fails:
1. diagnose it
2. fix it
3. rebuild
4. continue

Do not leave avoidable build or test failures for the user.

ARCHITECTURAL DISCIPLINE

Do not rewrite completed phases simply because you would personally structure them differently.

Extend existing abstractions where possible.

Do not create duplicate models, repositories, services, storage systems, navigation systems, or theme systems.

Before introducing a new abstraction, inspect whether an existing one already serves the purpose.

Do not bypass repositories by accessing storage directly from screens.

Do not put business logic directly inside large widgets when an existing service/repository layer is appropriate.

PRODUCT DISCIPLINE

Do not add features that are not part of the approved roadmap.

Do not add:
- unnecessary dashboards
- fake statistics
- fake notes
- fake review counts
- unnecessary gamification
- social features
- subscriptions
- authentication
- collaboration
- cloud sync
- attachments
- PDF support
- databases
- tags
- complex Notion-style features

unless a later phase explicitly requests them.

Do not build speculative features just because the architecture could support them.

DESIGN DISCIPLINE

Maintain:
- warm off-white background
- near-black primary typography
- restrained neutral greys
- Newsreader for editorial/display typography
- Inter for UI labels
- generous whitespace
- minimal borders
- minimal elevation
- calm editorial appearance
- large comfortable touch targets

Avoid:
- gradients
- excessive cards
- colorful dashboards
- excessive icons
- gamification graphics
- dense file-manager aesthetics
- unnecessary animations
- visual clutter

EMPTY STATES

Empty states are intentional.

Never populate the app with fake data simply to make screens look complete.

If functionality does not yet exist, show a truthful empty state.

VISUAL REVIEW POLICY

Visual review is deferred until the end unless a visual problem prevents functional testing.

If you notice something that might need visual refinement, record it under:

DEFERRED VISUAL REVIEW

Do not stop implementation for it.

BUG POLICY

Fix bugs immediately when they are:
- compile/build failures
- analyzer errors
- test failures
- crashes
- data loss
- broken navigation
- broken persistence
- obvious overflow
- broken core interactions

Defer subjective design refinements until the end.

PHASE CONTROL

Each phase prompt contains a STOP AFTER PHASE instruction.

In autonomous build mode, interpret that as:

"Do not start unrelated future work outside the roadmap."

It does NOT mean you should interrupt the user after every phase.

Continue to the next numbered phase automatically once the current phase passes its automated checks.

EXCEPTION — GENUINE BLOCKERS

Do not interrupt the user for ordinary implementation decisions.

However, stop and report if continuing would require:
- deleting or corrupting user data
- exposing secrets
- making an irreversible architectural change
- changing the core product direction
- introducing a dependency that conflicts with the project
- requiring credentials or external configuration that are unavailable
- making a choice that materially changes a previously approved requirement

For ordinary implementation choices, choose the simplest reasonable option and continue.

For visual imperfections, minor uncertainty, or subjective design decisions, continue and record them for later review.

FINAL REPORT

When the entire roadmap is complete, provide:
1. Summary of all phases completed
2. Files created
3. Files significantly modified
4. Automated tests performed
5. Build/analyzer results
6. Bugs fixed during autonomous development
7. Deferred visual-review items
8. Architectural concerns
9. Features intentionally not implemented
10. Recommended final manual testing checklist

Do not claim that visual behavior is perfect without human review.

BEGIN AUTONOMOUS BUILD MODE NOW.

ROADMAP

Phase 0 --- Project Foundation

STATUS: COMPLETED

Already established:

theme system

typography

Note model

Review model

Flashcard model

Quiz model

storage abstraction

note repository

review repository

review scheduler

AI service contract

app shell

initial screens

testing infrastructure

Verified:

flutter analyze passed

flutter test passed

flutter build web passed

mobile overflow checks passed

Do not redo Phase 0.

Phase 1 --- Home Experience

PHASE 1 — HOME EXPERIENCE

Phase 0 is COMPLETE and verified.

Do not redo or restructure Phase 0 unless a concrete implementation issue requires it.

Build the real Home experience.

The primary question is:

"What should I remember today?"

Build around:
1. Review
2. Continue learning
3. Recent notes
4. Creating a new note

Phase 2 has not yet implemented note creation.

DO NOT create fake notes.
DO NOT create fake review counts.
DO NOT create fake percentages.
DO NOT create fake streaks.
DO NOT create fake statistics.

YOUR MEMORY

When there are no review items:

"YOUR MEMORY"

"Nothing due for review."

Prepare the UI for future:
- reviews due
- review items
- estimated review time
- review action

Do not implement actual review scheduling yet.

CONTINUE LEARNING

Create the UI structure for a future continue-learning section.

If there is no content, keep it empty or omit it cleanly.

RECENT NOTES

Show recently edited notes when available.

If no notes exist:

"Your notes will appear here."

Provide a create-note action.

PRIMARY ACTION

Provide a clear:
"+ New note"

Do not create fake content.

DESIGN

Use the Phase 0 design system:
- warm off-white
- near-black text
- restrained greys
- Newsreader
- Inter
- generous whitespace
- minimal borders
- minimal icons
- no gradients
- no colorful dashboard widgets

Keep:
Review
Notes
Settings

Use repository abstractions.

Do not access storage directly from UI.

TEST:
- Home renders
- empty review state
- empty recent-notes state
- create-note action
- navigation
- no overflow

Check:
375x667
390x844
430x932
360x800

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 1.
Continue automatically to Phase 2.

Phase 2 --- Nested Notes

PHASE 2 — NESTED NOTES SYSTEM

Build the core note hierarchy.

PRODUCT PRINCIPLE

Everything is a note.

A note can contain child notes.

Example:

Business
    Ideas
        Smart Q Estates
        Service Apartments

There is no separate Folder model.

Use the existing:
- Note model
- parentId
- childrenIds
- serialization
- NoteRepository
- LocalNoteRepository
- storage abstraction

Do not create duplicate systems.

NOTES SCREEN

Replace the placeholder with a real hierarchy browser.

At root level display notes where:
parentId == null

Do not make this look like a file manager.

Avoid:
- folder icons
- dense rows
- excessive metadata
- card grids

CREATE ROOT NOTE

Add:
"+ New note"

Create a root-level note with:
- title
- optional subtitle
- optional content

Do not build the complete editor yet.

OPEN NOTE

Show:
- title
- subtitle
- child notes
- add child note
- navigation back to parent

CREATE CHILD NOTE

Provide:
"+ Add page"

Set:
parentId = currentNote.id

Support arbitrary depth:

Root
    Child
        Grandchild
            Great-grandchild

PERSISTENCE

Notes must survive application restart.

If Phase 0 only has in-memory persistence, extend it with the simplest appropriate persistent adapter.

Do not add cloud sync.

DELETE

Implement safe deletion.

Do not silently orphan children.

Prefer explicit subtree deletion with confirmation.

HOME

Connect Recent Notes to real NoteRepository data.

DO NOT IMPLEMENT:
- full rich editor
- AI
- summaries
- flashcards
- quizzes
- Teach Me
- review scheduling
- search
- authentication
- cloud sync
- collaboration
- attachments
- images
- PDFs
- tags
- databases
- folders

TEST:
1. root note
2. child
3. grandchild
4. persistence
5. reload
6. navigation
7. back navigation
8. deletion
9. child behavior
10. Home integration
11. empty states
12. overflow

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 2.
Continue automatically to Phase 3.

Phase 3 --- Note Editor

PHASE 3 — NOTE EDITOR

Build the primary writing and reading experience.

A note should feel like a clean digital page, not a form.

STRUCTURE

Back
Note actions

Title

Subtitle

Body

Child notes

Allow:
- edit title
- edit subtitle
- edit body
- safe autosave
- create child note
- open child note

Keep the editor lightweight.

Do not imitate Microsoft Word.

Do not create a huge toolbar.

Prioritize:
- typography
- reading comfort
- whitespace
- keyboard usability
- fast editing

Use existing rich-content architecture if present.

Do not attempt to reproduce the entire Notion editor.

Ensure notes cannot be accidentally lost.

Show child pages beneath the content.

Test:
- create
- title
- subtitle
- content
- navigate away
- return
- verify persistence
- edit
- verify persistence
- child note
- open child
- return

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 3.
Continue automatically to Phase 4.

Phase 4 --- Search & Discovery

PHASE 4 — NOTE DISCOVERY

Build note discovery.

Implement:
1. Search
2. Recently edited notes
3. Browse hierarchy

SEARCH

Search:
- title
- subtitle
- note content

Results should update efficiently.

RECENT NOTES

Show actual recently edited notes.

BROWSE

Allow navigation through nested notes.

Do not create a dense file-management interface.

Use repository/service layers for search.

Handle:
- empty results
- long titles
- special characters
- deeply nested notes
- mobile keyboard behavior

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 4.
Continue automatically to Phase 5.

Phase 5 --- AI Foundation

PHASE 5 — AI SERVICE FOUNDATION

Introduce the AI architecture.

Create a clean AI service abstraction.

Initial operations:
- summarizeNote
- generateFlashcards
- generateQuiz
- explainNote
- generateTeachMeSession

Keep AI independent from UI widgets.

Use structured response models.

Do not scatter API calls across screens.

SECURITY

Never expose private AI API keys in the Flutter client.

If a backend/proxy is required, use a server-side boundary.

Do not hard-code secrets.

Handle:
- loading
- success
- errors
- retry

AI must never silently modify original notes.

Generated material remains separate from source notes.

Do not automatically send every note to AI.

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 5.
Continue automatically to Phase 6.

Phase 6 --- AI Note Actions

PHASE 6 — AI NOTE ACTIONS

Add an AI action to notes:

✦ AI

Options:
- Summarize
- Create flashcards
- Create quiz
- Explain simply

SUMMARIZE

Return a concise summary.

FLASHCARDS

Generate:
- question
- answer
- source note

QUIZ

Generate:
- question
- options
- correct answer
- explanation
- source note

EXPLAIN

Explain in simpler language.

Use a lightweight bottom sheet or equivalent.

Do not let AI dominate the editor.

Show loading and error states.

Allow retry.

Do not modify original note content.

Test:
- short notes
- long notes
- empty notes
- nested notes
- loading
- errors
- retry
- response parsing

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 6.
Continue automatically to Phase 7.

Phase 7 --- Flashcards

PHASE 7 — FLASHCARD SYSTEM

Turn generated flashcards into a real review experience.

FLOW

Note
↓
AI
↓
Flashcards
↓
Review
↓
Again / Hard / Good / Easy

Show one card at a time.

Start with the question.

User taps:
"Show answer"

Then show the answer and:

Again
Hard
Good
Easy

Persist flashcards separately from source notes.

Store source-note relationship.

Use existing ReviewItem and ReviewRepository architecture.

Do not create duplicate review models.

Test:
- generation
- persistence
- reveal
- rating
- next card
- session completion
- reopening

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 7.
Continue automatically to Phase 8.

Phase 8 --- Quizzes

PHASE 8 — QUIZ EXPERIENCE

Build a real quiz session.

FLOW

Start
↓
Question
↓
Answer
↓
Feedback
↓
Next
↓
Completion

Start with multiple choice.

Each question:
- question
- options
- correct answer
- explanation
- source note

After answering:
- indicate correct/incorrect
- explain why
- continue

Completion should show:
- questions answered
- correct answers
- concepts needing more review

Do not create elaborate gamification yet.

Record performance for later review scheduling.

Test:
- rendering
- answer selection
- correct answers
- incorrect answers
- feedback
- next question
- completion
- persistence

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 8.
Continue automatically to Phase 9.

Phase 9 --- Teach Me

PHASE 9 — TEACH ME

Build the interactive AI tutoring experience.

Purpose:

Help the user retrieve and understand what they already wrote.

FLOW

Note
↓
Teach Me
↓
AI asks question
↓
User answers
↓
AI evaluates answer against source material
↓
AI explains gaps
↓
Next question

The user's notes are the primary knowledge source.

Do not present unrelated AI knowledge as if it came from the user's notes.

Create a calm conversational learning interface.

Example:

"Let's see what you remember."

AI:
"What are the two main factors discussed in this note?"

User answers.

AI:
"Good. You mentioned X. You missed Y."

Then ask another question.

Track:
- questions asked
- answers
- concepts understood
- concepts needing review
- completion

Do not build social or competitive gamification.

Test:
- start
- question generation
- answer submission
- response parsing
- next question
- completion
- errors
- retry

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 9.
Continue automatically to Phase 10.

Phase 10 --- Review Engine

PHASE 10 — REVIEW ENGINE

Implement the actual memory/review system.

Use existing:
- ReviewItem
- ReviewRepository
- ReviewSchedulerService

Do not create another scheduling system.

Use the existing SM-2-based implementation as the starting point.

Handle:
- new items
- again
- hard
- good
- easy
- due dates
- history

Do not claim the algorithm is scientifically perfect.

REVIEW SOURCES

Review items may originate from:
- flashcards
- quiz concepts
- Teach Me sessions

Do not turn every word of every note into a review item.

Focus on meaningful concepts.

DUE QUEUE

Build a real queue.

Do not create fake items.

HOME

Connect Your Memory to real review data.

When empty:
"Nothing due for review."

When populated:
show real count and review entry point.

Test:
- new item
- good answers
- poor answers
- due dates
- overdue
- queue
- persistence
- restart

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 10.
Continue automatically to Phase 11.

Phase 11 --- Memory-Driven Home

PHASE 11 — MEMORY-DRIVEN HOME

Make Home the intelligent entry point.

Primary question:

"What should I remember today?"

Priority:

1. Reviews due
2. Continue learning
3. Recent notes
4. Create note

YOUR MEMORY

When reviews exist, show:
- real count
- useful grouping
- reliable estimated session length if available
- Start Review

Never fabricate statistics.

CONTINUE LEARNING

Use actual note history.

Show the most relevant recently opened or edited note.

RECENT NOTES

Show actual notes.

NEW NOTE

Keep creation accessible.

If there is nothing to review and no notes, make the empty state feel intentional.

Do not introduce unnecessary gamification.

Test:
- empty
- one note
- multiple notes
- one review
- multiple reviews
- mixed state
- completed review
- recent notes

Run:
flutter analyze
flutter test
flutter build web

Fix failures automatically.

STOP AFTER PHASE 11.
Continue automatically to Phase 12.

Phase 12 --- Polish & Final QA Preparation

PHASE 12 — POLISH AND FINAL QA PREPARATION

The core product is implemented.

Do not add major new features.

Audit:

1. Navigation
2. Persistence
3. Note creation
4. Nested notes
5. Note editing
6. Search
7. AI actions
8. Flashcards
9. Quizzes
10. Teach Me
11. Review scheduling
12. Home review queue
13. Error handling
14. Loading states
15. Empty states
16. Keyboard behavior
17. Layout overflow
18. Accessibility basics

Fix:
- crashes
- build errors
- analyzer errors
- test failures
- broken navigation
- data loss
- persistence failures
- obvious overflow
- broken loading states
- broken error states

Look for obvious performance problems:
- unnecessary rebuilds
- repeated expensive work
- duplicate AI requests
- excessive persistence writes
- blocking UI work

AI COST CONTROL

AI should only run when needed.

Avoid duplicate requests caused by rebuilds or navigation.

DESIGN CONSISTENCY

Check:
- typography
- spacing
- buttons
- empty states
- navigation
- theme consistency

Do not introduce a new visual language.

TEST:

flutter analyze
flutter test
flutter build web

Check:
375x667
390x844
430x932
360x800

Also test:
- long text
- deeply nested notes
- large notes
- AI failure
- persistence after restart

Fix all objective problems.

FINAL REPORT

Provide:
1. complete feature list
2. files created
3. major files modified
4. automated tests
5. build results
6. bugs fixed
7. deferred visual issues
8. known limitations
9. manual testing checklist
10. recommended next steps

Do not claim production readiness solely from automated testing.

STOP AFTER PHASE 12.

FINAL MANUAL TEST AFTER AUTONOMOUS BUILD

Once Antigravity finishes, use the app yourself before adding anything
else.

Test this exact journey:

Open app
↓
Create "Business"
↓
Create "Smart Q Estates"
↓
Create "Service Apartments"
↓
Write a real note
↓
Close app
↓
Reopen
↓
Find the note
↓
Ask AI to summarize it
↓
Generate flashcards
↓
Review flashcards
↓
Take quiz
↓
Try Teach Me
↓
Complete review
↓
Return Home

Then perform a dedicated bug-fix and UX refinement pass based on actual
use.

Important Rule

Autonomous mode should mean:

Don't interrupt me for routine decisions.

It should NOT mean:

Make irreversible or dangerous decisions without me.

The genuine-blocker rules above are the exception.