so we should have ai be able to calculte from text you get


I want to add a **direct Notion import feature** to my existing Flutter notes app.

Start implementing this immediately. Do not just explain or give me a plan.

### FEATURE

Add:

**Settings → Import from Notion**

The user should be able to:

1. Tap **Connect Notion**
2. Authenticate with their Notion account using Notion OAuth
3. Grant the required permissions
4. See their accessible Notion pages
5. Select pages to import
6. Tap **Import**
7. Convert the selected Notion pages into native notes in this app

### IMPORTANT

* Use the official Notion API and OAuth flow.
* Keep the architecture clean and compatible with the existing Flutter project.
* Do not redesign the existing app.
* Follow the existing minimalist UI/design system.
* Imported content must become **native notes**, not remain dependent on Notion.
* Preserve useful structure such as titles, headings, paragraphs, bullet lists, numbered lists, checkboxes, images where reasonably possible, and page hierarchy.
* Handle loading, authentication errors, permission errors, empty pages, and failed imports gracefully.
* Never expose Notion client secrets in the Flutter client. Use a secure backend/server-side component where required.
* First inspect the existing project structure and note model before making changes.
* Then begin implementation immediately.
* Work phase-by-phase, validating each step before moving to the next.
* Run `flutter analyze` and the appropriate tests after implementation.

Start by inspecting the existing codebase and implementing the Notion connection/import foundation now.
