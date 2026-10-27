# Folding a fix into the commit that introduced it

Fold only commits that belong to open pull requests: the rewrite starts
above the commit the default branch points at, never inside merged history.
Fold only when nothing else is editing the tree, and never in the middle of
an edit wave, because unfinished edits would enter history.
The rewrite happens in a separate worktree, so the working tree is never
touched.

## 1. Prepare

- `git fetch origin`; every branch in the stack matches its fetched tip,
  or has only your unpushed commits on top (`SKILL.md`, last section).
- Normalize line endings as the repository's `.gitattributes` says: a
  repository that sets `core.safecrlf` refuses `git add` on a mismatch.
- `git status --short -uall`: every untracked file is folded in too,
  so delete strays or move them out first.
- Scan the changes for secrets before they enter history.

## 2. Snapshot the tree to a hidden ref

The snapshot is the target state and the backup at once. Take one before a
long edit wave as well, so a crash cannot lose the work. It uses a private
index seeded from `HEAD`, so neither the real index nor the files change,
and a tracked file `.gitignore` matches is kept. Every exit code is
checked: a failed `git add` otherwise leaves an empty snapshot that looks
fine.

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$index = Join-Path ([IO.Path]::GetTempPath()) "snapshot-$stamp.index"
$previous = $env:GIT_INDEX_FILE
$env:GIT_INDEX_FILE = $index
try {
    git read-tree HEAD
    if ($LASTEXITCODE -ne 0) { throw 'git read-tree failed' }
    git -c core.safecrlf=false add -A
    if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
    $tree = (git write-tree).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'git write-tree failed' }
}
finally {
    $env:GIT_INDEX_FILE = $previous
    Remove-Item -LiteralPath $index -ErrorAction SilentlyContinue
}

$identity = @('-c', 'user.name=backup', '-c', 'user.email=backup@example.invalid')
$parent = (git rev-parse HEAD).Trim()
$snapshot = (git @identity commit-tree $tree -p $parent -m 'working-tree backup').Trim()
if ($LASTEXITCODE -ne 0) { throw 'git commit-tree failed' }
git update-ref "refs/backup/wip-$stamp" $snapshot
```

`git diff --name-status HEAD $snapshot` and `git status --short -uall` list
the same paths. A file comes back with `git show <snapshot>:<path>`.

## 3. Rewrite in a worktree

Work on the top branch of the stack, so one rewrite covers every pull
request in it.

1. `git worktree add <scratch folder> -b fold-<stamp> <top branch>`.
2. For each change, find the commit that introduced the thing being fixed:
   `git blame -L <start>,<end> <top branch> -- <path>` for changed lines,
   `git log --format='%h %s' -- <path>` for a whole file. A new file goes to
   the commit of the same concern in the right pull request.
3. In the worktree, for each target commit: take its paths from the
   snapshot (`git checkout <snapshot> -- <paths>`, or
   `git rm -q --ignore-unmatch -- <path>` for a deletion),
   then `git commit --fixup=<target>`. When one file holds fixes for two
   commits, stage each part from a trimmed patch (`git apply --cached`)
   and make one fixup per target.
4. Squash the fixups without an editor ever opening (git 2.44 or later):

   ```powershell
   $env:GIT_EDITOR = 'true'
   $env:GIT_SEQUENCE_EDITOR = 'true'
   git rebase --autosquash (git merge-base HEAD origin/<default>)
   ```

   The environment variables outrank any `core.editor` setting.
   A fix next to lines a later commit touched stops the rebase twice:
   at the fixup, where the file takes the target's content plus the fix
   only, and at the later commit, where it takes the snapshot's content.
   Resolve each with `git add` and `git rebase --continue` when the answer
   is plain; otherwise `git rebase --abort` and ask.

## 4. Verify before moving anything

- The rebase finished: its exit code was 0, `git status` shows no rebase in
  progress, and no subject starts with `fixup!`. Check this first, because a
  stopped rebase leaves the branch at its old tip, whose tree already equals
  the snapshot.
- The rewritten tip's tree equals the snapshot's:
  `git rev-parse fold-<stamp>^{tree}` against `$tree`.
  This catches a wrong conflict resolution or a missed path.
- The commit count, subjects, authors and author dates are as expected,
  and `git range-diff` against the old line shows only the fixes.

## 5. Move the branches and push

1. Move the checked-out branch with a compare-and-swap, which fails if it
   moved meanwhile: `git update-ref refs/heads/<branch> <new> <old>`,
   then `git reset -q` so the index follows; the files already match.
2. Point each lower branch at its counterpart commit,
   push them all with the leases in `SKILL.md`, and check each pull request.
3. Clean up: remove the worktree, then delete `fold-<stamp>` and the backup
   ref. The backup holds every untracked file that was in the tree,
   including any that held a secret.
