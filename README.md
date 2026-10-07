# daily-case

"Sprawa Dnia" is a daily crime puzzle for Android and iOS (Flutter). Every day all players get the same case. They must name the culprit, the motive and the piece of evidence that proves it. There are three attempts and hints cost points. At midnight (Polish time) the case lapses and its solution is revealed in the archive the next day.

Fictional cases are generated daily by an AI model, which also checks that each puzzle is fair. Cases inspired by real events are written by hand and uploaded with a script.

The player-facing content (UI and case scenarios) is in Polish. Everything else in the repository is in English.

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
                                   ▲
pg_cron (hourly) ──HTTP──▶       Edge Function generate-case
                                   ├─ seed (era, setting, deduction mechanism)
                                   ├─ model: save_case (structured output)
                                   ├─ fair-play validation
                                   ├─ 3× blind solver (no solution, no hints)
                                   └─ saves up to 7 days ahead
```

- **The solution never reaches the app early.** The server checks each accusation and returns only per-element hits (🟩🟥). The solution is sent after a win or from the next day.
- **7-day buffer.** If generation fails or the API is down, the game keeps running and the function retries every hour.
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

Requirements: a Supabase account (the free plan is enough to start), the [Supabase CLI](https://supabase.com/docs/guides/cli) and an Anthropic API key.

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
     -d '{"wait": true}'
   ```
   The response contains `approved` (or `pending`) and the case title. Rejected attempts and their reasons are stored in `private.generation_log`.
5. **Schedule.** Replace the URL and secret in `supabase/sql/cron_generate.sql` and run it once in the SQL Editor.
6. **Handwritten cases (optional).** Upload the 5 cases from `assets/cases.json` for consecutive days starting 8 October:
   ```bash
   SUPABASE_URL=https://<project-ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<key> \
     node tools/import_cases.mjs 2026-10-08
   ```
   The generator skips days that already have a case. Keep the `service_role` key local; never put it in the app or the repository.

### generate-case parameters

The call requires the `x-cron-secret` header. The body is optional:

- `{"wait": true}` waits for the result (for manual testing). Without it the work runs in the background and the response is `202`.
- `{"date": "2026-10-20"}` targets a specific day inside the buffer.

### Review before publishing

With `REQUIRE_REVIEW=true` new cases are stored as `pending` and are not shown to players. Queries for the buffer, the generation log and player results are in `supabase/sql/review.sql`. The 7-day buffer leaves time for review. A rejected day is regenerated.

```sql
update private.cases set status = 'approved' where case_date = date '2026-10-15' and status = 'pending';
update private.cases set status = 'rejected' where case_date = date '2026-10-15' and status = 'pending';
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
| `GEN_MODEL` | `claude-sonnet-5-5` | model that writes the case |
| `SOLVER_MODEL` | same as `GEN_MODEL` | model that checks solvability |
| `SOLVER_RUNS` | `3` | number of independent solver runs that must agree |
| `DAYS_AHEAD` | `7` | how far ahead to keep the buffer |
| `REQUIRE_REVIEW` | `false` | `true` = cases wait for manual approval |
| `GEN_MAX_TOKENS` | `8000` | maximum length of the model response |

One invocation produces one case: generation plus 3 solver runs in parallel, a few model calls per day. Edge Functions on the free plan have a 150 s limit. If `cron.job_run_details` shows interrupted calls with no entry in `generation_log`, lower `GEN_MAX_TOKENS` or `SOLVER_RUNS`.

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
  models/                          case, case kind, player progress
  state/game_controller.dart       screen state
  screens/, widgets/               UI
supabase/
  migrations/                      database schema and RPC functions
  functions/generate-case/         case generator (Deno)
  sql/cron_generate.sql            schedule
  sql/review.sql                   case review and statistics
tools/import_cases.mjs             upload of handwritten cases
test/                              rules, controller and case file tests
```

## Tests

```bash
flutter test
deno test supabase/functions/generate-case/validate_test.ts
```

## Game rules (source of truth: SQL in `supabase/migrations`)

- Day 1 is 7 October 2026. Days are counted in the Europe/Warsaw time zone.
- Score: 100 − 20 per missed attempt − 10 per hint, minimum 10.
- Streak: consecutive days with a solved case, counted if the last win was today or yesterday.
- After midnight accusations are rejected and the case moves to the archive with its solution.

When changing these numbers, update both the SQL and `lib/logic/rules.dart` (local mode).

## Case data format

`assets/cases.json` and the database use the same keys: `id`, `title`, `kind` (`fictional` | `inspired`), `note` (required for `inspired`), `docket`, `place`, `date`, `brief`, `suspects`, `evidence` (`hint: true` for hint evidence), `motives`, `solution` (`culprit`, `motive`, `evidence`, `explain`). After adding a case, run `flutter test`; `cases_data_test.dart` checks references and that the case is solvable without hints.
