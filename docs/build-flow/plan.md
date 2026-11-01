# Plan: Tigris on big screens

Status: approved 2026-11-01.

## Who it's for
One person, a writer who takes church notes and writes stories, using Tigris on a laptop or desktop through the web or Mac version, alongside the phone.

## The problem
Above phone width, Tigris is the phone screen centered in a big window. Moving between notes means going in and out of full pages, and it ignores the mouse and keyboard.

## First version must-haves
- **Two panes:** a notes sidebar on the left and the open note on the right, in one window. Notes open beside the list, not on a new page.
- **Sidebar tree:** notes inside notes with arrows, as dense single lines, showing the open note. Includes search and a new-note button.
- **Move and resize:** drag the divider to resize the sidebar, and hide or show it.
- **Note pane:** a calm centered writing column, with the path to the note (breadcrumb) along the top.
- **Mouse details:** hover states, right-click menu on notes (add page inside, rename, delete), and the line drag handles already built.
- **Formatting without a bottom bar:** a small toolbar that appears over selected text, plus typing `/` for block types.
- **Keyboard shortcuts:**
  - New note: Cmd/Ctrl+N
  - Search: Cmd/Ctrl+K
  - Bold and italic: Cmd/Ctrl+B and Cmd/Ctrl+I
  - Hide sidebar: Cmd/Ctrl+\
- **Secondary screens:** Settings, Backup and Login shown as centered panels on big screens, not stretched pages.
- **Remember** the last open note, sidebar width and expanded notes on each device.

## Left out for now
- Multiple tabs or split notes
- Dragging notes between places in the sidebar
- Full menu bar and native Mac window styling
- Any change to the phone layout, except sharing the same colors and type
- Windows and Linux versions

## Main screens and journeys
1. Open Tigris: the last note is open and the sidebar shows where it sits.
2. Browse: expand a note, click a child, and the writing pane changes straight away.
3. Write: new note, title, Enter, write, format selected text.
4. Find: Cmd/Ctrl+K, type, press Enter to open.
5. Organize: right-click a note to add a page, rename or delete.
6. Narrow the window: below the breakpoint it becomes the phone layout, with nothing lost.

## Technical approach
- Stay in Flutter, with one codebase.
- Switch layouts by window width, not by platform, with a breakpoint at 900px.
- Reuse `NotesTreeList`, `NoteDetailScreen` content and `BlockNoteEditor`, separating the note content from its full-page shell so it can sit in a pane.
- No changes to storage, sync or backup.
- The web version stays limited by browser storage. This plan doesn't change that.
