# Tigris build checklist

A calm writing app: as simple as Apple Notes, with Notion's notes inside notes.
Built in this order, so each step rests on something solid.

## Done, not yet committed

- [x] New notes screen: list, search, expandable notes inside notes
- [x] New writing page: title, then writing, with the toolbar only while writing
- [x] New look: plain white or charcoal, one font (Inter)

## 1. Keep notes safe and fast

- [ ] Move notes from `SharedPreferences` to an on-device SQLite database
- [ ] Carry existing notes across automatically
- [ ] Remove the silent "treat as empty" load that can overwrite all notes
- [ ] Save only the note that changed, not every note on each autosave
- [ ] Retry cloud saves that fail, instead of waiting for the next full sync

## 2. Rearrange lines like Notion

Dragging already exists in the editor (`block_note_editor.dart`), but it hasn't
been tested on the new design.

- [ ] Test dragging by mouse and on a phone, and fix what breaks
- [ ] Make the drag handle easy to find without cluttering the page
- [ ] Show clearly where a line will land
- [ ] Drag a line onto a page to move it inside that page
- [ ] Keep nested lines together when their parent line moves

## 3. Make it solid on a real phone

- [ ] Test the writing page with the on-screen keyboard
- [ ] Check typing speed in long notes
- [ ] Fix anything awkward found in daily use

## 4. Writing comforts for stories

- [ ] Font choice, including a serif option
- [ ] Word count
- [ ] Distraction-free mode
- [ ] Reorder pages inside a note, for chapters and scenes

## 5. Plugins and scripture

- [ ] Simple plugin structure, so new tools can be added later
- [ ] Scripture plugin: type a reference like `John 3:16` and pull in the verse
- [ ] Bundle KJV and WEB, which are public domain, so it works offline in church
- [ ] Look into licensed translations (NIV, ESV) if wanted

## 6. Real AI quizzes

- [ ] Build real quiz generation on the server (today it isn't implemented)
- [ ] Quiz a single note, or a whole notebook with everything nested inside it
- [ ] Base questions only on your notes, each linking back to its source
- [ ] Make it fun: score and "try the ones I missed", kept simple
- [ ] Remove the fake AI (`LocalAiService`) from the live app

## 7. Tidy up

- [ ] Decide what stays: flashcards, Teach Me, Review, Tasks, glossary, Notion import
- [ ] Remove old code nothing uses, such as `notes_screen.dart` if unneeded
- [ ] Replace the old `plans.md` and the default `README.md`
