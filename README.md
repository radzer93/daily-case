# daily-case

"Daily Case" is a daily crime puzzle for Android and iOS (Flutter). Every day there are three cases, one per difficulty level (easy, medium, hard), and all players on a level get the same case. Players choose a level on first launch and can switch at any time. They must name the culprit, the motive and the piece of evidence that proves it. There are three attempts and hints cost points. At midnight (Polish time) the case lapses and its solution is revealed in the archive the next day.

Fictional cases are generated daily by an AI model. Every case passes automatic validation, blind solver runs and an AI editor before it is published, so no manual review is needed. Cases inspired by real events are written by hand and uploaded with a script.

The player-facing content (UI and case scenarios) is in Polish. Everything else in the repository is in English.

UI texts live in `lib/l10n/app_pl.arb` and are generated with `flutter gen-l10n` (configured in `l10n.yaml`, also run by `flutter pub get` and `flutter run`). To change or add a text, edit the ARB file, never the generated `app_localizations*.dart`. A new language is a new `app_<code>.arb` file with the same keys.

On first launch players give their date of birth. Only the result is stored (`daily-case:age-gate` = `allowed` or `denied`), never the date. Players under 16 (`minimumAge` in `lib/logic/rules.dart`) cannot continue.

## Architecture

```
Flutter (lib/)                   Supabase
─────────────────                ─────────────────────────────────────────────
SupabaseGameBackend ──RPC──▶     public.get_today_case / submit_accusation / ...
  anonymous sign-in                │  (security definer, enforce the rules)
                                   ▼
                                 private.cases      (case: public + secret part)
                                 private.attempts   (player accusations)
                                 private.hint_unlocks
                                 private.case_feedback (ratings and reports)
                                   ▲
pg_cron (every 15 min) ──HTTP──▶ Edge Function generate-case
                                   ├─ seed (place, era, setting, mechanism, level, intensity)
                                   ├─ model (Gemini by default): structured JSON output
                                   ├─ fair-play validation for the level
                                   ├─ saves a draft
                                   ├─ next run: 3× blind solver (no solution, no hints) → verified
                                   ├─ next run: AI editor scores 7 criteria → approved or rejected
                                   └─ buffer of 7 days × 3 levels
```

- **The solution never reaches the app early.** The server checks each accusation and returns only per-element hits (🟩🟥). The solution is sent after a win or from the next day.
- **7-day buffer.** If generation fails or the API is down, the game keeps running and the function retries on the next run.
- **Three-step generation.** One run writes a draft, the next run checks it with the solver, the one after that sends it to the editor, so a single run makes at most 3 model calls. A draft whose check fails 3 times is rejected, and a day and level that failed 3 times in the last 6 hours is skipped for a while, so one bad slot never blocks the queue.
- **Local mode.** Without Supabase configuration the app plays the cases from `assets/cases.json` under the same rules. Useful for UI work.

## Running the app

```bash
flutter pub get
flutter test

# local mode (no server)
flutter run

# with the server: copy env.example.json to env.json and fill it in
flutter run --dart-define-from-file=env.json
```

`env.json` is git-ignored. Only put the public key (anon / publishable) there, never `service_role`.

## Deploying the backend (Supabase)

Requirements: a Supabase account (the free plan is enough to start), the [Supabase CLI](https://supabase.com/docs/guides/cli) and a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey) (the free tier is enough: about 5 model calls per case, 3 cases a day). A Google AI Pro subscription does not include API access; the key is separate. Anthropic can be used instead with `LLM_PROVIDER=anthropic`.

1. **Project.** Create a project in the Supabase dashboard. Under *Authentication → Sign In / Providers* enable **Allow anonymous sign-ins**.
2. **Database.**
   ```bash
   supabase login
   supabase link --project-ref <project-ref>
   supabase db push
   ```
3. **Function secrets.** Copy `supabase/functions/.env.example` to `supabase/functions/.env`, fill it in, then:
   ```bash
   supabase secrets set --env-file supabase/functions/.env
   supabase functions deploy generate-case --no-verify-jwt
   ```
4. **First case (manual test):**
   ```bash
   curl -X POST https://<project-ref>.supabase.co/functions/v1/generate-case \
     -H "x-cron-secret: <CRON_SECRET>" -H "Content-Type: application/json" \
     -d '{"wait": true, "full": true, "date": "2026-10-11", "difficulty": "easy"}'
   ```
   The response contains `approved` (or `rejected`) and the case title. `full` writes, solves and reviews the case in one call, which can take a few minutes and may hit the 150 s limit of the free plan; in that case call without `full` three times. Rejected attempts and their reasons are stored in `private.generation_log`.
5. **Schedule.** Replace the URL and secret in `supabase/sql/cron_generate.sql` and run it once in the SQL Editor.
6. **Handwritten cases (optional).** Upload the 5 cases from `assets/cases.json` for consecutive days starting 8 October on one level (`--difficulty`, default `easy`, which matches their 3 suspects and 6 pieces of evidence):
   ```bash
   SUPABASE_URL=https://<project-ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<key> \
     node tools/import_cases.mjs 2026-10-08 --difficulty=easy
   ```
   The generator skips day and level pairs that already have a case. Keep the `service_role` key local; never put it in the app or the repository.

### generate-case parameters

The call requires the `x-cron-secret` header. The body is optional:

- `{"wait": true}` waits for the result (for manual testing). Without it the work runs in the background and the response is `202`.
- `{"date": "2026-10-20", "difficulty": "hard"}` targets a specific day and level inside the buffer (level defaults to `medium`).
- `{"full": true}` runs all remaining stages (draft, solver, editor) in the same call.

Without a target, a run first advances the oldest unfinished case (`draft` → solver, `verified` → editor); if there is none, it writes a draft for the earliest missing day and level.

### Automatic quality control

Statuses: `draft` → `verified` (solver agreed) → `approved` | `rejected` (editor). `pending` is used only with `REQUIRE_REVIEW=true` or `EDITOR_BORDERLINE=pending`.

**AI editor.** Scores the full case (with solution) from 1 to 5 on `logic`, `fairness`, `difficulty_fit`, `setting`, `language`, `content` and `originality`, and lists concrete issues.

- any score ≤ `EDITOR_REJECT_SCORE` (default 2) → rejected,
- all scores ≥ `EDITOR_MIN_SCORE` (default 4) → approved,
- anything in between is borderline and follows `EDITOR_BORDERLINE`: `reject` (default), `pending` or `approve`. Keep `reject` if nobody reviews cases: a `pending` case would leave the day empty.

A hard case that scores at least `EDITOR_MIN_SCORE` on everything except `difficulty_fit` is not rejected: it moves to the earliest free medium slot in the buffer (`meta.moved_from`, `meta.editor.downgraded_from`), which saves the model calls of a new case.

A rejected case whose structure is sound (`content` and `difficulty_fit` at least `EDITOR_MIN_SCORE`, nothing at or below `EDITOR_REJECT_SCORE`) gets one revision (`EDITOR_REVISIONS`): on the next run the generator fixes the editor's issues without changing ids or the solution, and the case goes through the solver and the editor again.

Every generated case also carries a secret reasoning plan: `deduction` (steps, each listing the public evidence or statements it combines) and `false_leads` (innocent suspects who look guilty and what clears them). The minimum numbers of steps, combined steps and false leads grow with the level and are enforced by validation.

Scores, issues and the decision are stored in `meta.editor`. A rejected slot is regenerated on a later run.

**Player feedback.** After playing a case to the end (won, three misses or expired after at least one accusation) players can rate it with 1–5 stars and report a problem (`unfair`, `contradiction`, `language`, `inappropriate`, `other`). Stored in `private.case_feedback`.

**Weekly report.** Run `supabase/sql/weekly_report.sql` in the SQL Editor once a week (read-only). The first query returns `admin_quality_report(7)`: generation stages, editor rejections and, for each published case, players, solve rate, average rating, reports and flags:

| Flag | Condition |
|---|---|
| `easy_too_hard` | easy, ≥ 10 players, solved < 30% |
| `medium_too_hard` | medium, ≥ 10 players, solved < 15% |
| `too_easy` | medium or hard, ≥ 10 players, solved > 90% |
| `low_rating` | ≥ 5 ratings, average < 3 |
| `many_reports` | ≥ 3 reports |

**Email alerts.** The `quality-alert` function runs every hour and sends one email per new problem (each problem is reported once):

| Flag | Condition | Window |
|---|---|---|
| `inappropriate` | at least 1 "inappropriate" report | today's and yesterday's cases |
| `many_reports` | ≥ `ALERT_MIN_REPORTS` (3) reports | today's and yesterday's cases |
| `low_rating` | ≥ `ALERT_MIN_RATINGS` (5) ratings, average < `ALERT_LOW_RATING` (2.5) | today's and yesterday's cases |
| `missing_case` | no published case for a level today | from `ALERT_TODAY_HOUR` (08:00), after the overnight generation |
| `missing_tomorrow` | no published case for a level tomorrow | from `ALERT_TOMORROW_HOUR` (18:00) |

`inappropriate` and `missing_case` are marked `[URGENT]` in the subject; `missing_tomorrow` is informational. Every case alert includes the ready kill-switch query. Sent alerts are stored in `private.alerts`.

Setup:

1. Create a free account at [Resend](https://resend.com) **with the same email address that should receive alerts** and create an API key. Without a verified domain Resend only delivers from `onboarding@resend.dev` to the account owner's address; with your own domain, set `ALERT_FROM`.
2. Set the secrets and deploy:
   ```bash
   supabase secrets set RESEND_API_KEY=<key> ALERT_EMAIL=<your address>
   supabase functions deploy quality-alert --no-verify-jwt
   ```
3. Test without sending (`dry_run` lists what would be sent):
   ```bash
   curl -X POST https://<project-ref>.supabase.co/functions/v1/quality-alert \
     -H "x-cron-secret: <CRON_SECRET>" -H "Content-Type: application/json" -d '{"dry_run": true}'
   ```
4. Run `supabase/sql/cron_alerts.sql` once in the SQL Editor (after `cron_generate.sql`, which creates the Vault secrets).

**Kill switch.** Setting a published case to `rejected` hides it immediately; if its date is today or later, the generator writes a replacement on the next runs. Players who already played it keep their results in the stats, but the case disappears from the app and the archive, so use it only for serious problems.

```sql
update private.cases set status = 'rejected' where case_date = date '2026-10-15' and difficulty = 'medium' and status = 'approved';
```

Other queries for the buffer, the generation log and player results are in `supabase/sql/review.sql`. With `REQUIRE_REVIEW=true` cases the editor approves are stored as `pending` and wait for manual approval:

```sql
update private.cases set status = 'approved' where case_date = date '2026-10-15' and difficulty = 'medium' and status = 'pending';
```

### Schedule management

Run `supabase/sql/cron_generate.sql` once. Running it again fails on `vault.create_secret` because the names already exist; change values with `vault.update_secret` or in the dashboard (Integrations → Vault).

```sql
select * from cron.job;
select * from cron.job_run_details order by start_time desc limit 20;
select cron.unschedule('daily-case-generate');
```

### Generator settings

| Variable | Default | Meaning |
|---|---|---|
| `LLM_PROVIDER` | `gemini` | `gemini` or `anthropic` |
| `GEMINI_API_KEY` | | key from Google AI Studio (for `gemini`) |
| `ANTHROPIC_API_KEY` | | key from the Anthropic Console (for `anthropic`) |
| `GEN_MODEL` | `gemini-3.8-flash` / `claude-sonnet-5-5` | model that writes the case |
| `SOLVER_MODEL` | same as `GEN_MODEL` | model that checks solvability |
| `GEMINI_THINKING` | `high` | Gemini thinking level: `minimal`, `low`, `medium`, `high` |
| `SOLVER_RUNS` | `3` | number of independent solver runs that must agree |
| `SOLVER_DELAY_MS` | `2000` | pause between solver runs (free-tier rate limits) |
| `SOLVER_THINKING` | `medium` | Gemini thinking level for the solver |
| `DAYS_AHEAD` | `7` | how far ahead to keep the buffer |
| `DARK_RATIO` | `0.25` | share of cases written in the darker 16+ tone |
| `EDITOR_MODEL` | same as `GEN_MODEL` | model that reviews the case |
| `EDITOR_THINKING` | `high` | Gemini thinking level for the editor |
| `EDITOR_MIN_SCORE` | `4` | every criterion must reach this to approve |
| `EDITOR_REJECT_SCORE` | `2` | any criterion at or below this rejects |
| `EDITOR_BORDERLINE` | `reject` | `reject`, `pending` or `approve` for cases between the thresholds |
| `EDITOR_REVISIONS` | `1` | how many times a fixable rejected case is revised |
| `EDITOR_MAX_TOKENS` | `12000` / `2000` | output limit for the editor |
| `REQUIRE_REVIEW` | `false` | `true` = cases the editor approves wait for manual approval as `pending` |
| `GEN_MAX_TOKENS` | `24000` / `8000` | output limit for the case; raise it if responses are cut off |
| `SOLVER_MAX_TOKENS` | `8000` / `1500` | output limit for one solver run |

**Free-tier quota.** Each case costs 2 + `SOLVER_RUNS` model calls (generation, solver runs, editor), and rejected cases cost the same again. With a daily limit of about 20 requests per model, use `SOLVER_RUNS=1` and, if possible, point `SOLVER_MODEL` and `EDITOR_MODEL` at another model with its own quota. When the provider reports an exhausted daily quota, the generator logs a `quota` entry and skips runs until the reset time, checking again at least every 3 hours, without counting it as a failure of the draft.

Model names and free-tier quotas change; check the current list and your quota in Google AI Studio. Free-tier prompts may be used by Google to improve its products, which is acceptable here because only seeds and fictional cases are sent.

### Known limitation

Anonymous accounts are easy to recreate (for example by clearing app data). A player with several accounts can learn per-element hits from extra attempts on the same day. That is acceptable for a casual game. Before adding leaderboards with prizes, add sign-in (Apple / Google) or rate-limit account creation.

## Project structure

```
assets/cases.json                  handwritten cases (local mode + import)
lib/
  config.dart                      SUPABASE_URL / SUPABASE_ANON_KEY from --dart-define
  data/game_backend.dart           game interface
  data/supabase_backend.dart       production (RPC + anonymous sign-in)
  data/local_backend.dart          local mode, same rules as the server
  logic/rules.dart                 day number, scoring, share text
  l10n/                            ARB texts, generated localizations, label helpers
  models/                          case, case kind, player progress
  state/game_controller.dart       screen state
  screens/, widgets/               UI
supabase/
  migrations/                      database schema and RPC functions
  functions/generate-case/         case generator (Deno)
  functions/quality-alert/         email alerts about reported or missing cases
  sql/cron_generate.sql            schedule
  sql/review.sql                   case review and statistics
  sql/weekly_report.sql            weekly quality report
  sql/cron_alerts.sql              hourly email alerts schedule
tools/import_cases.mjs             upload of handwritten cases
test/                              rules, controller and case file tests
```

## Tests

```bash
flutter test
deno test supabase/functions/generate-case/validate_test.ts
deno test supabase/functions/quality-alert/email_test.ts
```

## Game rules (source of truth: SQL in `supabase/migrations`)

- Day 1 is 7 October 2026. Days are counted in the Europe/Warsaw time zone.
- Three levels per day: easy (3 suspects, 6 pieces of evidence), medium (4 suspects, 6), hard (4 suspects, 7, two combined mechanisms). Each level has its own attempts.
- Score: 100 − 20 per missed attempt − 10 per hint, minimum 10, multiplied by ×1 / ×1.5 / ×2 for easy / medium / hard.
- Streak: consecutive days with at least one solved case on any level, counted if the last win was today or yesterday.
- After midnight accusations are rejected and the case moves to the archive with its solution.

When changing these numbers, update both the SQL and `lib/logic/rules.dart` (local mode).

## Case data format

`assets/cases.json` and the database use the same keys: `id`, `title`, `kind` (`fictional` | `inspired`), `note` (required for `inspired`), `docket`, `place`, `date`, `brief`, `suspects`, `evidence` (`hint: true` for hint evidence), `motives`, `solution` (`culprit`, `motive`, `evidence`, `explain`). After adding a case, run `flutter test`; `cases_data_test.dart` checks references and that the case is solvable without hints.
