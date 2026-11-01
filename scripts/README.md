# TestFlight Feedback

`scripts/feedback` pulls new TestFlight feedback (screenshot and crash submissions) from the
App Store Connect API and writes a Markdown report to `docs/feedback/`.

`docs/feedback/` is **gitignored and stays on this Mac**: it holds tester names, emails, screenshots
and crash logs. What gets committed is the triaged review doc, `docs/YYYYMMDD_testflight_feedback.md`.

| Path (in `docs/feedback/`) | Contents |
|---|---|
| `YYYYMMDD_feedback.md` | One report per day; later runs that day append to it |
| `assets/` | Screenshots (`FB-0012-1.png`) and crash logs (`FB-0013.crash`) |
| `.state.json` | Which submissions have already been fetched, and their FB-#### numbers. Don't edit by hand. |

## One-time setup

1. In App Store Connect, go to **Users and Access → Integrations → App Store Connect API** and
   generate a **Team key** with the Developer role or higher. Download the `.p8` file (one-time download).
2. Move it out of Downloads:
   ```sh
   mkdir -p ~/.appstoreconnect && chmod 700 ~/.appstoreconnect
   mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/
   chmod 600 ~/.appstoreconnect/AuthKey_*.p8
   ```
3. Create `~/.appstoreconnect/funfitness.json`:
   ```json
   {
     "keyID": "XXXXXXXXXX",
     "issuerID": "00000000-0000-0000-0000-000000000000",
     "appID": "1234567890",
     "keyPath": "~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
   }
   ```
   - **keyID** and **issuerID** are shown on the API keys page.
   - **appID** is the numeric Apple ID under App Store Connect → FunFitness → **App Information**.
   - You can point to a different config file with the `ASC_CONFIG` environment variable.

The key and config never go in the repo. `*.p8` is in `.gitignore` as a safety net.

## Usage

```sh
scripts/feedback            # fetch new feedback, write today's report
scripts/feedback --dry-run  # list what's new without writing anything
```

The first run takes a few seconds because Swift compiles the script. Each run only adds
submissions it hasn't seen before. Deleting feedback in App Store Connect doesn't affect reports
already written here.

## Reviewing

1. Run `scripts/feedback` after each TestFlight build, or weekly.
2. Open the new report in Xcode or any Markdown viewer.
3. Ask Claude to "triage today's feedback". It groups duplicates, sorts items into bugs, suggestions
   and questions, and points to the likely code.
4. Update each **Status**: `new` · `fixed in (N)` · `won't fix` · `need info` · `duplicate of FB-####`.
5. Reply to testers by email. The API can't send replies.
6. Put the triage (issue, cause, fix, size, status) in the review doc and commit that. The raw report
   and assets stay local.
