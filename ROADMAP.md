# Tigris build checklist

A calm writing app: as simple as Apple Notes, with Notion's notes inside notes.
Built in this order, so each step rests on something solid.

## Done

- [x] New notes screen: list, search, expandable notes inside notes
- [x] New writing page: title, then writing, with the toolbar only while writing
- [x] New look: plain white or charcoal, one font (Inter)

## 1. Keep notes safe

- [x] Move notes from `SharedPreferences` to an on-device SQLite database
- [x] Carry existing notes across automatically
- [x] Stop treating unreadable data as empty, which could overwrite all notes
- [x] Save only the note that changed
- [ ] Confirm the move on a real phone with real notes

## 2. Log in, work offline, sync

Built and covered by automated tests with a simulated cloud. Not yet run
against real Firebase with a real account.

- [x] Clear login screen, with Google as the main option
- [x] Show a quiet status: saved on this device, syncing, synced, offline
- [x] Sync as soon as the internet returns, not only on a 30-second timer
- [x] Download only what changed, instead of every note on each sync
- [x] Keep both versions if the same note was edited on two devices offline
- [x] Keep one account's notes out of another account after signing out
- [ ] Test it with a real account: edit offline on two devices, reconnect, lose nothing

## 3. Backup to Google Drive

Sync keeps devices matched. A backup is a separate copy you can return to.

Built for Android and iOS with a simulated Drive. Not yet run against real Drive.

- [x] Export all notes to a file you can read without Tigris
- [x] Save that backup to Google Drive, by hand and then automatically
- [x] Restore from a backup
- [ ] Turn on the Drive API and test with your real Google account

## 4. Bring everything over from Notion

A first version exists, but needs a token pasted in and each page shared by hand.

- [ ] Simple "Connect Notion" sign-in, using a small secure server step
- [ ] Import the whole workspace, keeping notes inside notes
- [ ] Keep headings, lists, checkboxes, images and links looking native
- [ ] Importing again updates notes instead of creating duplicates
- [ ] Show a clear report of anything that couldn't be brought over
- [ ] Test it on your real Notion workspace

## 5. Rearrange lines like Notion

Dragging now works with a mouse, confirmed in the browser. Finger dragging is
only covered by automated tests so far.

- [x] Fix dragging with a mouse
- [ ] Test dragging with a finger on a real phone
- [ ] Make the drag handle easy to find without cluttering the page
- [ ] Show clearly where a line will land
- [ ] Drag a line onto a page to move it inside that page
- [ ] Keep nested lines together when their parent line moves

## 6. Make it solid on a real phone

- [ ] Test the writing page with the on-screen keyboard
- [ ] Check typing speed in long notes
- [ ] Fix anything awkward found in daily use

## 7. Writing comforts for stories

- [ ] Font choice, including a serif option
- [ ] Word count
- [ ] Distraction-free mode
- [ ] Reorder pages inside a note, for chapters and scenes

## 8. Plugins and scripture

- [ ] Simple plugin structure, so new tools can be added later
- [ ] Scripture plugin: type a reference like `John 3:16` and pull in the verse
- [ ] Bundle KJV and WEB, which are public domain, so it works offline in church
- [ ] Look into licensed translations (NIV, ESV) if wanted

## 9. Real AI quizzes

- [ ] Build real quiz generation on the server (today it isn't implemented)
- [ ] Quiz a single note, or a whole notebook with everything nested inside it
- [ ] Base questions only on your notes, each linking back to its source
- [ ] Make it fun: score and "try the ones I missed", kept simple
- [ ] Remove the fake AI (`LocalAiService`) from the live app

## 10. Tidy up

- [ ] Decide what stays: flashcards, Teach Me, Review, Tasks, glossary, Notion import
- [ ] Remove old code nothing uses, such as `notes_screen.dart` if unneeded
- [ ] Replace the old `plans.md` and the default `README.md`
