# Spec: Add search to the notes app

## Problem / goal
The notes app (index.html + notes.js) lists notes but has no way to find one.
Add a client-side search box that filters the visible notes list as the user types.

## Scope
Files expected to change:
- `index.html` — add a search input above the notes list
- `notes.js` — add filter logic wired to the search input

Non-goals (explicitly out of scope):
- Persistence (localStorage/backend) — notes stay in-memory as today
- Fuzzy matching, ranking, or highlighting of matched text
- Any framework, build step, or dependency — stays vanilla JS
- Styling beyond what is needed for the feature to be usable

## Behavior
- A search input with placeholder "Search notes..." appears above the list.
- Filtering is case-insensitive substring match on the note text.
- Filtering happens live on every keystroke (`input` event).
- Clearing the search shows all notes again.
- Adding a new note while a search is active: the note is added to the full
  list, and the currently visible list respects the active search filter.
- If no notes match, the list shows a single "No matching notes" message
  (not an empty, confusing blank area).

## Exit criteria (binary, checkable)
1. `index.html` contains a search input with id `search`, and the page loads
   with no console errors.
2. Typing "rice" (any case, e.g. "RICE") into the search box shows exactly 1
   note ("Buy rice and dal") and hides the other 2 seed notes.
3. Clearing the search box restores all 3 seed notes.
4. Typing text that matches nothing (e.g. "zzz") shows the "No matching notes"
   message and zero note items.
5. With "rice" typed in search, adding a new note "rice flour" via the Add
   button results in 2 visible notes; clearing search shows all 4.
6. `node --check notes.js` passes (no syntax errors).

## Verification plan
Mode 2 (static/tests) as the floor: `node --check` plus a Node-based DOM
simulation test that exercises criteria 1–5 against the real notes.js logic;
output saved to `.loop/notes-search/evidence/`. Mode 1 (in-browser) if browser
tooling is available in this environment; otherwise the DOM-simulation
evidence stands in and a manual checklist is provided in handoff.md.
