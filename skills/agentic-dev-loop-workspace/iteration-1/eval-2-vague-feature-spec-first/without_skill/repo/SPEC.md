# Spec: Search for Notes App

## Goal
Let the user quickly find notes by typing into a search box. The app is a
single-page vanilla-JS notes list (no build step, no dependencies) — search
must stay dependency-free and work offline in the browser.

## Requirements

### Functional
1. A search input appears above the notes list.
2. Typing filters the visible notes live (on every keystroke).
3. Matching is case-insensitive substring match against the note text.
4. Multiple words in the query are treated as AND terms — a note matches
   only if it contains every term (order-independent).
   e.g. "supplier friday" matches "Call supplier about Friday delivery".
5. Matched portions of the note text are highlighted with `<mark>`.
6. A result count is shown while a query is active ("2 of 3 notes").
7. If nothing matches, an empty state is shown ("No notes match \"xyz\"").
8. A Clear (×) button and the Escape key both clear the query and restore
   the full list.
9. Adding a new note keeps the current filter applied (the new note appears
   only if it matches the active query). Notes are never deleted or mutated
   by search — it is a pure view filter.

### Non-functional
- No external libraries; keep the existing plain-script structure.
- Rendering must be XSS-safe: note text goes in via DOM text nodes, never
  string-concatenated innerHTML (highlighting splits text and inserts
  `<mark>` elements around text nodes).
- Filtering logic (`filterNotes`, `splitByMatches`) is written as pure
  functions so it can be unit-tested in Node without a DOM.

### Out of scope
- Persistence (notes are in-memory, as before).
- Fuzzy matching / ranking.
- Debouncing (list is tiny; keystroke filtering is fine).

## Acceptance checks
- Empty query → all notes visible, no count, no empty state.
- "rice" → only "Buy rice and dal", with "rice" highlighted, count "1 of 3".
- "RICE" → same result (case-insensitive).
- "supplier friday" → matches the supplier note (AND across terms).
- "zzz" → no notes, empty-state message visible.
- Escape or × → query cleared, all notes back.
- Add note "rice cakes" while searching "rice" → it appears in results;
  clearing the search shows all 4 notes.
