---
name: writing-documentation
description: >-
  Writes and reviews README.md and the Markdown documents in docs/ to a house
  style: timeless prose, footnote-style link definitions in named groups,
  hand-wrapped lines, en-US spelling, and links in place of re-explained
  third-party material. Use when adding a document, editing one, or auditing
  documents for accuracy and staleness.
when_to_use: >-
  Trigger phrases: write a doc, update the docs, update the README, review
  docs/, add a document, are the docs accurate, check the docs for staleness,
  fix the links in a doc.
allowed-tools: Read Edit Write Grep Glob Bash WebFetch
---

A README introduces a project. A document in `docs/` explains the *reasoning*
behind rules that are stated elsewhere. Instruction files state rules;
documents explain them. Never restate a rule in a document that an
instruction file already owns, and never leave a rule only in a document —
non-agentic tools get instruction text injected and will never follow a link.

Both follow the conventions below.

## Write for a reader two years from now

The most common defect in documents is a true statement that stopped being
true. Prefer a sentence that cannot rot.

**Never write down:**

- A count of anything — "all five reviewers", "three lines", "the other two".
  Adding a sixth silently makes the sentence a lie.
- An inventory that lives in a folder — a table of the skills or agents that
  exist. Link the folder and let the reader look.
- Front matter, key names, or flags that belong to another file. Say a
  reviewer is "declared read-only in its front matter", not
  `disallowedTools: Write, Edit`.
- A list of which modules a script imports, or which files a workflow calls.
  Describe what the arrangement achieves.
- Speculation about what might be added later. It reads as a commitment and
  ages into a to-do list nobody owns.
- A number that is enforced somewhere else — a coverage target, a timeout,
  a version. Say the check reports it. Two copies of a threshold is one too
  many.
- Prices, plan names, or vendor tiers. They change and they date the
  document.
- What something used to be, or how it worked before a change. A reader
  compares the document only with what is true today; explain the current
  shape and why, not the history that led to it.

**Do write down:** the shape of the system, why it is shaped that way, what
breaks if you do it differently, and how to perform the task.

When something genuinely must be named — a secret, a variable, a workflow the
reader has to click — name it. The test is whether a reader could act without
it.

## Prefer someone else's explanation

If a passage re-explains a third-party tool, standard, or general practice,
replace it with a link and keep only this repository's stance.

Keep local: the reasoning behind a threshold this repository enforces, and
the reason *this* repository chose a thing. Link out: exception-handling
guidance, security checklists, editor menu paths, anything with a vendor's
name on it.

**Verify every URL by fetching it before committing it.** Vendor URLs move
constantly, and a plausible-looking path is often a 404. If a URL cannot be
confirmed, describe the destination in prose instead of guessing —
"check your editor's documentation for the exact name" beats a dead link.

## Structure

```markdown
# Title <!-- omit from toc -->

One or two sentences on what this document answers.

#### Table of Contents <!-- omit from toc -->

- [First Section](#first-section)
```

- `####` for the table of contents heading is deliberate: it does not deserve
  h2 sizing.
- The title and the table of contents itself are both left out of the table
  of contents.
- A short document needs no table of contents at all.
- Every fenced block declares a language. Use `text` for anything with no
  better answer.

## Line wrapping

Prose is hard-wrapped by hand, and where the break falls is deliberate. The
target and the hard limit are my user-level width rule, unless the
repository says otherwise. Two rules, in this order:

1. **Break at punctuation or a phrase boundary** — a comma, a semicolon, a
   colon, an em dash, the end of a clause. Never mid-phrase, and never
   separating a preposition from what it governs.
2. **Then fill the line** — get as close to the target as rule 1 allows.

Rule 1 wins, so a line that ends well short of the target because the next
clause would not fit is correct. But do not break early when the phrase
*does* fit: `activities like side-by-side code comparisons,` is one unit and
belongs on one line, even though it runs right up to the target.

```markdown
- **Run the analyzer** before every commit,
  even when the change looks too small to matter.
```

Not this — the break lands mid-phrase, splitting "too small to matter":

```markdown
- **Run the analyzer** before every commit, even when the change looks too
  small to matter.
```

Keep parentheticals, link labels, and quoted phrases whole. Running past the
target is allowed occasionally when the alternative is an awkward break; past
the hard limit, never.

Applying this to an edited paragraph means re-wrapping the whole paragraph,
not just the line you touched.

## Link definitions

Links are footnotes, not inline URLs: write `[label][name]` in the prose and
define `name` once, at the end of the document. That keeps the prose readable,
lets one URL serve several mentions, and groups related destinations.

Groups appear in this order. Each sits under its own comment, with a blank
line after the comment and a blank line before the next group's comment. A
group with nothing in it is omitted.

```markdown
<!-- Repository files -->

[styleGuide]: ./guides/Style.md
[overview]: ./Overview.md
[readme]: ../README.md

<!-- Other repositories -->

[issues]: https://github.com/owner/repository/issues
[sibling]: https://github.com/owner/other-repository

<!-- GitHub documentation -->

[githubDocs]: https://docs.github.com/

<!-- Public websites -->

[commonMark]: https://commonmark.org/
```

- **Repository files** — paths inside this repository. Sorted the way an
  editor's explorer shows a tree: at each level, folders before files, each
  alphabetical. So a file inside `docs/` precedes a file at the repository
  root. Use `./` for a sibling in the same folder, not a bare filename.
- **Other repositories** — a link to any repository on a hosting site: this
  repository's own issues, pull requests, or wiki, or another repository's
  pages and files, whoever owns it. A gist counts. Alphabetical by reference
  name.
- **GitHub documentation** — optional. Anything on GitHub's own public web
  pages: its documentation, blog, and changelog. Use the group only when a
  document has many such links; otherwise they go in the last group.
  Alphabetical by reference name.
- **Public websites** — everything else, alphabetical by reference name.

Keep the names exactly as written. Each says what its group holds, and none
is a variant of another: similar names let links drift into the wrong group,
until the groups mean nothing. Choose by what the URL points at — a path in
this checkout, a repository on a hosting site, GitHub's own web pages, or
anything else.

## Language

- **en-US** throughout: behavior, honor, summarize, license as a noun.
- Sentence-case prose; a document's existing heading style wins over any
  preference of yours.
- Functional emoji are welcome as scanning aids. Decorative ones are not.

## Reviewing

A documentation review is a fact-check, not a copy-edit. In order:

1. **Verify every claim against the code.** Counts, file names, key names,
   flags, thresholds. Read the file being described; do not trust the
   description. This finds the real defects.
2. **Check cross-document consistency.** If two documents state the same
   threshold, one of them is wrong now or will be.
3. **Check that every reference resolves** and that no definition is unused.
4. **Fetch external URLs.**
5. Only then, spelling and grammar.

Report findings before editing unless told otherwise, and separate *wrong*
from *stylistically different*. Say plainly when a claim you flagged turns out
to be correct — a false accusation costs the reader more than the nit was
worth.

## Where a repository differs

These rules apply in every repository unless told otherwise. Where a
repository's own instructions differ — its link groups, its widths, its
heading style — the repository wins.
