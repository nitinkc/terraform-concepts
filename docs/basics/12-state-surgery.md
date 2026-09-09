# 12 — State surgery

**Folder:** none yet — this is the highest-value gap in the stage.

Three commands for reconciling config, state and reality when they drift apart. Practising
them on a `local_file` costs nothing and takes seconds; practising them on a GCP resource
costs money and nerve. Do it here first.

## 12a — Rename without destroying

Rename `local_file.pet` to `local_file.greeting_file` in your code, then move the state
entry to match:

```bash
terraform state mv local_file.pet local_file.greeting_file
terraform plan   # should show no changes
```

Without the `state mv`, Terraform would read the rename as "one resource deleted, one
created" and destroy the file. The resource address is part of its identity as far as state
is concerned.

## 12b — Remove from state, leave the real thing alone

```bash
terraform state rm local_file.greeting_file
ls -la /tmp/helloFruits.txt   # still exists on disk
terraform plan                # now wants to "create"
```

The file is now unmanaged: it exists, but Terraform has forgotten it.

**Watch what happens next, because this is provider-specific.** Applying now will
**silently overwrite** the existing file. `local_file` has no "already exists" API error to
protect you. Compare with `google_service_account`, which rejects a duplicate `account_id`
outright — see [Lab 6](../gcp/02-lab-notes.md#lab-6-state-surgery-mv-rm-import), where step
6b's plan *fails* rather than clobbering.

Good instinct to build: **don't assume every provider protects you the same way.** Cloud
APIs often turn a state-loss mistake into a loud error; local and file-based providers
often turn it into silent data loss.

## 12c — Re-adopt via import

```hcl
resource "local_file" "greeting_file" {
  filename = "/tmp/helloFruits.txt"
  content  = "Hello World! Default Text coming from the variable"
}
```

```bash
terraform import local_file.greeting_file /tmp/helloFruits.txt
terraform plan   # compare the content field for drift
```

**`import` only populates state.** It does not write or validate your HCL. If the `content`
in your config doesn't match the file on disk, the very next plan shows a diff and offers
to overwrite reality with what your code says. Making the config match is your job.

That's the same trap as [Lab 11 Part C](../gcp/02-lab-notes.md#lab-11-import-drift-detection),
where a bucket imported with `location = "US"` in the HCL but `us-central1` in reality
produces an immediate diff.

## The three in one line

| Command | Effect on state | Effect on the real thing |
|---|---|---|
| `state mv` | Renames the entry | Nothing |
| `state rm` | Deletes the entry | Nothing — now unmanaged |
| `import` | Creates an entry | Nothing — now managed |

None of the three touches real infrastructure. All three change what Terraform believes,
which is why the next `plan` after any of them is the one that matters.

---

Theory: [§13 State lifecycle](../theory/13-state-lifecycle.md) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [Provisioners and archive_file](13-provisioners-and-archive.md)
