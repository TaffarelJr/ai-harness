---
name: coauthor
description: >-
  Co-writes a substantial document with me — a proposal, spec, PRD, RFC, or
  design doc — from a context dump, through section-by-section drafting, to a
  reader test by a fresh subagent. Use when a document will be read by people
  who were not in this conversation.
when_to_use: >-
  Trigger phrases: coauthor this, draft a proposal, write the spec, write up
  an RFC, help me write a design doc, write a PRD.
argument-hint: "[kind of document, or its topic]"
disable-model-invocation: true
metadata:
  origin: https://github.com/anthropics/skills/tree/main/skills/doc-coauthoring
  commit: dbd4588
  license: none (idea only; no text copied)
---

We are writing a document for readers who were not here. It is finished when
a reader who was not here can use it.

## 1. Context first

Ask in one message: what kind of document, who reads it, and what they should
understand or decide afterwards. If a template or an earlier document sets
the shape, read it.

Then ask me to dump everything else, unorganized: background, links,
constraints, rejected alternatives, stakeholder concerns. Read what I point
to. Do not draft yet.

Then ask a few clarifying questions, numbered so I can answer in shorthand.
Ask only what is genuinely mine to decide — a priority, a position, a
constraint nobody wrote down. If the context or a sensible default answers
one, answer it yourself, say which, and move on.

## 2. Structure

Propose the sections for this kind of document and agree them with me. Create
the file with every heading and a one-line placeholder under each, so every
later edit has something to replace. Ask where it lives if the repository
does not say.

## 3. Section by section

Start with the section with the most unknowns, usually the core proposal;
leave the summary for last. For each section:

1. Where it turns on a choice — an approach, a scope line, a trade-off —
   give 2–3 candidates, what each trades off, and a recommendation. I pick.
   Where there is nothing to choose, skip this. Candidates stay in the
   conversation; the document records the choice and the reason.
2. Draft the section into the file.
3. I say what to change. Edit by targeted replacement of the passage; never
   reprint or rewrite the section or the document. When I edit the file
   myself, read my change and carry its taste into the next section.
4. After three rounds with nothing substantial, ask what could go without
   loss.

When most sections are done, read the whole document once for flow,
repetition, contradiction, and filler. Every sentence carries weight.

## 4. Reader test

Spawn a fresh `sonnet` subagent. Give it the document's path and nothing
else — not this conversation, not what the document is meant to say:

> You are a reader this document was written for. You have only the
> document. List the questions you would still have after reading it: what
> it assumes you know, what is ambiguous, what contradicts itself. Rank them
> by how much each would block you. If nothing important is left, say so.

Resolve every question: answer it in the document, cut what prompted it, or
bring it to me when only I can answer. After substantial changes, test again
with a new subagent. Done when no blocking question remains.

## 5. Hand-off

Give the finished document to the `writing-documentation` skill for wrapping, link
definitions, and language. Then I read it myself; I own it.

Where a repository's own instructions differ — a template, a section list, a
location for documents — they win.
