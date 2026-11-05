# Implementation plan: Inbox organization: markets, teams, and categories

Ticket 1 of the Support Tool PRD. Codebase: this repo (Chatwoot 4.18, **Community Edition** build).

## Constraints that shape the design

- **CE only.** CI deletes `enterprise/` before building (`.github/workflows/choplife-ghcr.yml`). Nothing here may live in or depend on `enterprise/`. Upstream already has a premium "Required Conversation Attributes" feature (`conversation_required_attributes` in `config/features.yml`), but its server-side enforcement is in `enterprise/`, so we build our own resolve guard. We do not reuse that premium flag.
- **One website per market.** Each market runs its own website, and each website embeds its own web widget (`Channel::WebWidget`, one `website_token` per site). The backend is deployed per country too: identity-service reads `COUNTRY` from env. So **the inbox is the reliable source of a conversation's market**. We map each inbox to a market once in settings, and every conversation inherits that market on creation.
- **Test as CE.** `enterprise/` is still on disk locally and overrides core classes via `prepend_mod_with` (e.g. `ConversationPolicy`, `ActionService`). Run dev and specs with the CE edition (`CW_EDITION=ce`, as CI does) so we don't depend on behaviour that disappears in production.
- **Upstream merges.** Keep changes in new files/tables where possible and keep edits to upstream files small, so future Chatwoot upgrades stay easy.

## Decisions

1. **One Chatwoot account** for all markets, so the Head of Support can compare markets and teams in one place.
2. **Market codes are ISO-3166 alpha-2** (UG, SL, …), matching the `COUNTRY` our backend services use. One market per website.
3. **Market source: inbox first, then contact.**
   - Each website's widget inbox and any per-market WhatsApp or social inbox is mapped to its market.
   - The **support email is shared by all markets**, so its inbox has no market and its conversations take the contact's market.
   - The contact gets a market the first time they chat on a market website, which collects their email (via `setUser` for logged-in players, the pre-chat form for guests). Later emails from that address then match the same contact.
   - If a sender has never chatted on a website, an agent sets the market once and it is saved on the contact.
   - WhatsApp and social channels should be one per market where possible.
4. **Team routing by market is configuration, not code.** Adding `market_id` to the filter keys makes it an automation-rule condition, so "market = UG → assign team Uganda" is set up in Settings → Automation. This only applies if teams are organised by country.
5. **Any agent can correct the market.** The change is logged in the conversation.
6. **"Waiting"** = open conversation whose last player message is unanswered (`waiting_since IS NOT NULL`). Pending (bot) and snoozed conversations are not counted.
7. **Categories:**
   - The tree supports up to 5 levels; the content starts with 2 (category → subcategory).
   - The agent must pick a **leaf**, so the full path is always set.
   - The tree includes an "Other → Other" fallback.
8. **Admins manage categories, markets and team names.** The Head of Support has the admin role.

## Open points for the PRD owner (Ticket 1)

| # | Question | Plan default until answered |
|---|---|---|
| O1 | A3 says a category must be set before **any** resolution. May **system resolutions** skip the rule? These are auto-resolve after inactivity, the player ending the chat, bots, muting and blocked contacts. Blocking them would leave conversations stuck open. | They skip it. They show in an "Uncategorised resolved" saved view for leads to tidy weekly, and count against the 95% target. |
| O2 | Should a **missing market** also block resolving? This is not in the PRD, but it helps reach the 95% target. | Not blocked. The guard is written so it can be switched on with a single condition. |
| O3 | A1 says the market comes "from the player account or the channel". Is **channel + contact** acceptable, or is a direct lookup in the player database required? | Channel + contact. A direct lookup can be added later (needs an API from our backend). |

## Inputs needed from the support team

- The list of markets with codes, and which website/widget and WhatsApp number belongs to each.
- How teams are organised: by country (then set up decision 4) or by topic.
- The first category list, drafted by the Head of Support from the last month's conversations: 6–10 categories with 3–8 subcategories each, plus "Other → Other". Review monthly; if "Other" passes ~5%, add the missing category.

---

## 1. Data model

### `markets`
| column | type | notes |
|---|---|---|
| account_id | bigint, not null | |
| name | string, not null | e.g. "Uganda" |
| code | string, not null | ISO-3166 alpha-2, e.g. `UG`; unique per account |
| position | integer | sort order in lists |
| archived_at | datetime | soft delete: keeps old conversations and reports intact |

### `inboxes.market_id` (bigint, nullable, indexed)
Default market for every conversation in that inbox. Set in inbox settings. Left empty for shared inboxes (the support email).

### `contacts.market_id` (bigint, nullable, indexed with account_id)
The player's market, remembered across channels. Set when it is empty and the contact gets a conversation with a known market. The first value wins; it is not overwritten automatically. It can also be edited on the contact page.

### `conversations.market_id` (bigint, nullable, indexed with account_id)
- On create: `inbox.market_id`, else `contact.market_id`, else `nil` (shown as "No market" for agents to fill in).
- Agents can change it by hand. The change is logged as an activity message, like a team change.

### `conversation_categories`
| column | type | notes |
|---|---|---|
| account_id | bigint, not null | |
| parent_id | bigint, nullable | `nil` = top level |
| name | string, not null | unique among siblings |
| position | integer | order among siblings |
| depth | integer, not null | 1–5; validated, max 5 |
| ancestor_ids | integer[], default `{}` | set on create; nodes cannot be moved to another parent, so this never changes |
| archived_at | datetime | soft delete |

### `conversations.category_id` (bigint, nullable, indexed with account_id)
Stores the **leaf** the agent picked. Filtering by any level is `category_id = X OR X = ANY(categories.ancestor_ids)`. That query is cheap because the category table is small.

Removing a category that conversations still use **archives** it instead of deleting it. It disappears from pickers, but old conversations and reports keep their label.

Migrations follow the repo's foreign-key rule (Rails associations, no DB FKs). Backfill job, in batches: `conversations.market_id ← inboxes.market_id`, then `contacts.market_id ←` market of their most recent conversation that has one.

---

## 2. Backend

### Markets
- `app/models/market.rb`; `Inbox`, `Contact` and `Conversation` each `belongs_to :market, optional: true`.
- Set the market on conversation create: a `before_create` callback in `Conversation` (or a small concern): `inbox.market || contact.market`.
- Remember it on the contact: after a conversation's `market_id` is set (on create or by an agent), copy it to `contact.market_id` if that is empty.
- Email matching already works: Chatwoot finds the existing contact by sender email when a new email arrives, so the shared email inbox picks up the contact's market with no extra code.
- Each market website collects the email so the contact can be matched later:
  - Logged-in players: the website calls `window.$chatwoot.setUser(playerId, { email, name, phone_number })` when the widget loads. Nothing for the player to type.
  - Guests: enable the widget's **pre-chat form** with a required email field (inbox settings, no code).
- Contact API/UI: allow `market_id` in the contact update params, and show it on the contact panel.
- API: `Api::V1::Accounts::MarketsController` (index/create/update/destroy, admin only for writes), routes under `accounts/:account_id/markets`.
- Conversation update: allow `market_id` in the conversations update params (`permitted_update_params` in `conversations_controller.rb`); validate that it belongs to the account and isn't archived.
- Inbox update: allow `market_id` in the inbox params.

### Categories
- `app/models/conversation_category.rb`: validations (depth ≤ 5, name unique per parent, parent in same account), `leaf?`, `path_names` (e.g. "Withdrawal › Pending approval").
- API: `Api::V1::Accounts::ConversationCategoriesController`. Index returns the whole tree in one call. Create/update/destroy plus a `reorder` action. Writes are admin only.
- Conversation update: allow `category_id`; must be an active **leaf** in the account. Logged as an activity message.

### Resolve guard (`A conversation cannot be resolved until a category and subcategory are set`)
Enforce it at the entry points where **a person** resolves a conversation:
| path | file |
|---|---|
| Resolve button / status change | `app/controllers/api/v1/accounts/conversations_controller.rb#toggle_status` |
| Bulk resolve | `app/jobs/bulk_actions_job.rb` (skip uncategorised ones and report them back) and the bulk actions controller response |
| Macros run by an agent | `app/services/macros/execution_service.rb` → `ActionService#resolve_conversation` |

Implementation: one small service, `Conversations::ResolveGuard#check!(conversation)`, which raises a custom error (`lib/custom_exceptions/`) that renders as **422** with an i18n message (`CATEGORY_REQUIRED`). System paths (`Conversations::ResolutionJob`, widget/public API end-chat, `resolved!` in mute/bot) stay unguarded, per O1. If O2 is approved, the same guard also checks `market_id`.

### Filtering and counts
- Add `market_id` and `category_id` to the `conversations` block of `lib/filters/filter_keys.yml`. Then advanced filters, saved **custom views** (`custom_filters`) and **automation conditions** support them without new UI plumbing. `category_id` needs a custom clause in `app/services/filter_service.rb` so a parent matches its descendants.
- Quick filters on the list: accept `market_id` and `category_id` params in `app/finders/conversation_finder.rb` (next to `filter_by_team`).
- **Group counts** endpoint: `GET /api/v1/accounts/:id/conversations/group_counts?group_by=market|team&status=open`. It returns `[{ id, name, open_count, waiting_count }]` with one `GROUP BY` query. It is built on the same base scope as `ConversationFinder`, including `Conversations::PermissionFilterService`, so counts respect what the user can see (and Ticket 2's rules later).

### Payloads
- Add `market` and `category` (`id`, `name`, `code`/`path`) to `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` and `app/presenters/conversations/event_data_presenter.rb`, so the dashboard, websockets and webhooks all carry them.

### Reporting hook (prep for Ticket 3)
When a conversation resolves, store `market_id` and `category_id` on the resolution `ReportingEvent` (or a small side table). Later recategorisation then can't change historical figures. The columns are cheap to add now; Ticket 3 uses them.

---

## 3. Frontend (Vue 3, `<script setup>`, Tailwind only, i18n for all strings)

### Settings
- **Settings → Markets** (`routes/dashboard/settings/markets/`): list, add, rename, reorder, archive, with `code`. Copy the structure of `settings/labels/` and `settings/teams/`.
- **Settings → Categories** (`routes/dashboard/settings/categories/`): tree editor. Add a child (disabled at depth 5), rename, drag to reorder within a parent, archive. No moving between parents.
- **Inbox settings**: a "Market" select on the inbox's settings tab.
- Vuex/Pinia store modules + API clients for markets and categories (`app/javascript/dashboard/api/`), following existing `teams`/`labels` modules.

### Conversation view
- `components/widgets/conversation/ConversationSidebar.vue`: a new **Classification** panel at the top with:
  - Market select (pre-filled, editable).
  - Cascading category selects, one per level, until a leaf is reached; shows the full path once chosen.
- Conversation header: small market chip and category path.
- `components/buttons/ResolveAction.vue`: if the category isn't a leaf, don't call the API. Show a toast ("Choose a category and subcategory before resolving") and focus the category picker. Still handle the API's 422 in case someone else changed the category meanwhile.
- Bulk actions: after a bulk resolve, report "N resolved, M skipped — missing category".

### Inbox list
- `components-next/Conversation/ConversationCard/ConversationCard.vue`: market badge (code) + top-level category on each card.
- `components/ChatList.vue`: market and category quick-filter dropdowns next to the existing status/sort controls.
- **Sidebar** (`components-next/sidebar/Sidebar.vue`):
  - New **Markets** group listing each market with its open/waiting count. Clicking one filters the list to it. This satisfies "group the inbox by market with counts".
  - The existing **Teams** group gets the same open/waiting counts. Clicking a team already opens that team's conversations.
  - Both groups get their counts from the `group_counts` endpoint and refresh on the existing conversation websocket events (debounced).

### Advanced filter / custom views
- Add Market and Category to the filter attribute list in the conversation advanced-filter modal (the frontend counterpart of `filter_keys.yml`), with a select input fed from the stores.

---

## 4. Delivery plan (separate PRs)

| # | PR | Contents | Est. | Status |
|---|---|---|---|---|
| 1 | Markets: backend | migration, `Market` model, inbox + contact + conversation columns, auto-set on create (inbox → contact), remember market on contact, backfill, markets API, update params, payloads, filter key, finder param | 3–4 d | ✅ Done (branch `feat/inbox-markets`, not committed) |
| 2 | Markets: UI | Settings → Markets, inbox market select, conversation sidebar select, card badge, advanced filter + saved views, automation condition | 3 d | ✅ Done (same branch, not committed) |
| 3 | Team & market counts | `group_counts` endpoint; sidebar **Markets** group (route `/market/:id`, the market quick filter) and counts for Teams and Markets; live refresh; market on the contact panel | 2–3 d | ✅ Done (same branch, not committed) |
| 4 | Categories: backend | migration, model, tree API with reorder, conversation `category_id`, filter clause, resolve guard on the three paths, resolution snapshot columns | 3 d | ✅ Done (same branch, not committed) |
| 5 | Categories: UI | Settings → Categories tree, cascading picker, resolve-button guard, bulk feedback, filters, card display | 4 d | ✅ Done (same branch, not committed) |
| 6 | Hardening | request/model specs for guard, filters, counts and permissions; i18n; Swagger docs; seed data (markets per website, sample categories) | 2 d | ✅ Done (same branch, not committed) |

Total ≈ **3.5 weeks** for one developer. PRs 1–3 (markets + team view) can ship before categories.

### Progress log

**PR 1 – Markets backend (done, 2026-11-03)**
- Migrations `20261103100000_create_markets` and `20261103100001_add_market_indexes` (indexes built `concurrently`).
- `Market` model (`app/models/market.rb`): ISO code normalised to upper case and unique per account; name unique per account; `active`/`ordered` scopes.
- `MarketHandler` concern on `Conversation`: market set on create from inbox, else contact; first market is copied onto the contact; activity message when a person or automation changes it.
- `ContactMergeAction` keeps the market when contacts are merged.
- `Inboxes::BackfillMarketJob`: runs when an inbox is mapped to a market and fills existing conversations and contacts that have no market.
- API: `/api/v1/accounts/:id/markets` (admin-only writes; delete archives, `archived: false` restores). `market_id` accepted on conversation, inbox and contact update via `MarketParamsConcern` (unknown or archived market → 404, same as company IDs).
- Payloads: `meta.market` on conversations (API, websocket, webhooks); `market_id` on contacts and inboxes.
- Filters: `market_id` in `lib/filters/filter_keys.yml` (conversations and contacts); `?market_id=` on the conversation list.
- Verified with temporary request specs (also with `DISABLE_ENTERPRISE=true`) and the existing related specs. Permanent specs are left for PR 6.

**PR 2 – Markets UI (done, 2026-11-03)**
- **Settings → Markets** (`routes/dashboard/settings/markets/`): list with code, mapped inboxes and status; add/edit dialog; archive/restore. Admin only.
- **Inbox settings → Market** select ("No market (shared inbox)" for the support email). Saving triggers the backfill.
- **Conversation sidebar → Conversation Actions → Market** dropdown under Assigned Team (shows `Uganda (UG)`, "None" clears it).
- **Conversation card**: market code badge (tooltip shows the name).
- **Advanced filter / saved views**: "Market" attribute, including the client-side matcher (`store/modules/conversations/helpers/filterHelpers.js`) and edit-folder values (`customViewsHelper.js`).
- **Automation**: "Market" condition on conversation created/updated/opened/resolved and message created (UI in `automation/constants.js`, backend allow-list in `AutomationRule#conditions_attributes`). Verified with a temporary test that a "market = UG → assign team" rule assigns the team when a conversation is created (decision 4).
- Markets are loaded once at app start (`Sidebar.vue`), next to teams and labels.
- Strings only in `en` (`marketsMgmt.json` plus a few keys in existing files).
- Tested in the browser on local data: create markets, map the Acme Support inbox (backfill gave its 3 conversations and contacts `UG`), change a conversation's market (toast + activity note), filter by market, archive/restore.
- Moved to PR 3: the market quick filter as a sidebar **Markets** group (needs a `/market/:id` route through the conversation list, which is the same plumbing as the counts), and showing/editing the market on the contact panel.

**PR 3 – Team & market counts (done, 2026-11-03)**
- `GET /api/v1/accounts/:id/conversations/group_counts?group_by=team|market` (`Conversations::GroupCountsController`): open and waiting counts per team or market in one `GROUP BY`, scoped with `Conversations::PermissionFilterService`, so agents only count conversations in their inboxes. Waiting = open with `waiting_since` set.
- **Sidebar**:
  - Teams show an open count, plus an amber waiting count when it isn't zero (tooltip: "12 open · 3 waiting"). Uses the new `QueueCountLeaf.vue`.
  - New **Markets** group (active markets) with the same counts. It links to `/market/:id`.
- **Market route** `/market/:marketId` and `/market/:marketId/conversations/:id`, wired through `ConversationView` → `ChatList` → `ConversationList` → `ConversationItem`, URL helpers, back-navigation, the list API (`market_id`), tab counts and the client-side page filter. The list title shows the market name.
- **Live refresh**: counts reload (debounced, at most every 10 s under load) on the same events that refresh the tab counts, plus every new message (a reply clears "waiting"). Store module `conversationGroupCounts`.
- **Contact panel**: a Market row under Company, editable inline. It only changes the contact's market, never existing conversations.
- Tested with temporary request specs (counts, agent scoping, invalid group, list by market) and in the browser: counts appeared and updated without a reload; the Uganda list and conversation URLs work; replying dropped the waiting count from 2 to 1; editing the contact market saved.
- Local test data: conversations #5 and #6 ("Market test 1/2", Acme Support inbox) were created for this test. #5 has a test reply and its contact is set to Sierra Leone. Conversations #2 and #3 had been deleted from the dashboard before this test run (dev log, 16:43–16:44 UTC).


**PR 4 – Categories backend (done, 2026-11-03)**
- Migrations `20261103120000_create_conversation_categories` (table; `conversations.category_id`; `reporting_events.market_id` and `category_id`) and `20261103120001_add_conversation_category_index` (built `concurrently`).
- `ConversationCategory` (`app/models/conversation_category.rb`):
  - A tree up to 5 levels: `parent_id`, `depth`, and `ancestor_ids` (set once on create; categories can't move to another parent).
  - Names are unique among siblings (DB unique index plus validation).
  - `leaf?` (no active children), `path` ("Withdrawal › Pending approval"), and `subtree_ids` for filtering by any level.
- API `/api/v1/accounts/:id/conversation_categories`:
  - Flat list (the dashboard builds the tree), create (with `parent_id`), rename, `PATCH reorder` (sibling ids in their new order).
  - Delete archives the category **and everything below it**; `archived: false` restores the subtree, but only once its parent is active.
  - Writes are admin only.
- Conversations (`CategoryHandler` concern):
  - `category_id` is accepted on conversation update (`CategoryParamsConcern`). An unknown or archived category returns 404; a category that isn't the last level returns 422.
  - An activity note is added when it changes ("John set the category to Withdrawal › Pending approval").
  - Payloads: `meta.category` is `{id, name, ancestor_ids}` in the list API, plus `path` in websocket and webhook data.
- **Resolve guard** (`Conversations::ResolveGuard`, decision O1 default): a **person** can't resolve a conversation without a category.
  - Resolve button / `toggle_status` returns 422 "Choose a category and subcategory before resolving this conversation".
  - Bulk resolve skips uncategorised conversations; the API now returns `{ skipped_ids: [...] }` so the dashboard can say which ones were skipped.
  - Agent-run macros skip the resolve step and leave an activity note "Not resolved by … choose a category and subcategory first".
  - Not guarded: auto-resolve, the contact ending the chat, bots, automations, mute.
- **Filter**: `category_id` in `filter_keys.yml`. Filtering by a parent matches all categories below it (`Conversations::FilterService#filter_values`).
- **Reporting snapshot**: `conversation_resolved` reporting events store the conversation's `market_id` and `category_id` at the time it was resolved (for Ticket 3).
- Two existing specs that resolve as an agent now set a category first (`conversations_controller_spec` toggle test, `bulk_actions_job_spec`). `ConversationsController` is one line over the class-length limit, so the cop is disabled there with a comment.
- Tested with temporary request specs (also with `DISABLE_ENTERPRISE=true`): tree/depth/uniqueness, API permissions, reorder, archive/restore, leaf-only assignment, 422/404 cases, resolve guard on button, bulk and macro, auto-resolve still works, parent filter, reporting snapshot.
- Until PR 5 ships the category picker, agents can't resolve in the dashboard. **Don't deploy PR 4 without PR 5.**

**PR 5 – Categories UI (done, 2026-11-03)**
- **Settings → Categories** (`routes/dashboard/settings/categories/`, admin only):
  - The tree is indented by level.
  - Each row has: add subcategory (hidden at level 5), rename, move up/down among its siblings, and archive/restore. Archive and restore apply to the whole branch, and archived rows are shown struck through.
- Store module `conversationCategories`:
  - Getters `getChildren`, `getFlatTree`, `getPath` and `getPathOptions`.
  - Loaded once at app start, next to markets.
- **Conversation sidebar → Conversation Actions → Category** (`CategoryPicker.vue`):
  - One searchable dropdown per level ("Choose a category", then "Choose a subcategory", …).
  - It saves only when a last-level category is picked; clearing the first level removes the category.
  - An amber hint ("Pick down to the last level. Required before resolving.") shows until a category is saved.
- **Resolve guard in the UI**:
  - Resolve button / Alt+E: if the conversation has no category, it shows "Choose a category and subcategory before resolving this conversation", opens the details panel on Conversation Actions, scrolls to the picker and highlights it.
  - The list's context menu checks the same thing.
  - `toggleStatus` now passes API errors to the caller (it used to swallow them), so a 422 from the server is shown too.
- **Bulk resolve**: uncategorised conversations are left out before calling the API. The `skipped_ids` returned by the server are added, and the user sees "N conversations weren't resolved: choose a category first".
- **Filters / saved views**: "Category" attribute, options shown as full paths. Picking a parent also matches its subcategories, both on the server and in the client-side matcher.
- **Conversation card**: the category name (last level) next to the market badge; the tooltip shows the full path.
- Tested in the browser on local data:
  - Built Withdrawal (Pending approval, Not received) and Deposit (Failed); moved Deposit up; archived and restored it.
  - Resolve on uncategorised test conversation #6 was blocked and opened the picker.
  - Picked Withdrawal › Not received (activity note, card label), then resolved (Uganda count updated live).
  - The API filter on "Withdrawal" returned #6.
  - Bulk resolve was covered by the backend test, not clicked through in the browser.

**PR 6 – Hardening (done, 2026-11-03)**
- **Backend specs** (all also pass with `DISABLE_ENTERPRISE=true`, like the CE build):
  - Factories `markets` and `conversation_categories`.
  - Models: `market_spec`, `conversation_category_spec`, `concerns/market_handler_spec` (inbox → contact fallback, contact remembers its first market, merge, activity note), `concerns/category_handler_spec` (last level only, archived and other-account categories rejected, activity note).
  - Requests:
    - `markets_controller_spec` and `conversation_categories_controller_spec` (permissions, reorder, archive/restore subtree, `conform_schema`).
    - `conversations/group_counts_controller_spec` (counts and agent scoping).
    - `conversations_classification_spec` (setting market and category, 404/422 cases, resolve guard on toggle_status, bulk `skipped_ids`, parent-category filter, list by market).
  - Jobs and services: `inboxes/backfill_market_job_spec`, `macros/execution_service_resolve_guard_spec`, `conversations/resolve_guard_spec` (bots and auto-resolve not blocked).
  - Listeners: `automation_rule_listener_market_routing_spec` (market → team rule), `reporting_event_listener_snapshot_spec` (market and category stored on resolution).
- **Frontend specs**: getters for `conversationCategories` and `markets`, the `conversationGroupCounts` store, market/category filter matching and the market page filter (`marketCategoryFilters.spec.js`), and market URLs.
  - Writing them found a bug: the client-side filter didn't match a single filter value against a category's id list, so the list could hide matching conversations. Fixed in `equalTo` (`filterHelpers.js`).
- **Swagger**:
  - New paths for markets, conversation categories (including `reorder`) and `conversations/group_counts`, with resource and request schemas and parameters.
  - `market_id` / `category_id` added to the conversation update docs; the resolve rule is noted on `toggle_status`.
  - Rebuilt with `rails swagger:build`; no existing path or schema changed.
- **Seed data**: `Seeders::AccountSeeder` now creates markets (Uganda UG, Sierra Leone SL) and a sample category tree (Withdrawal, Deposit, Account, Other → Other) from `lib/seeders/seed_data.yml`.
- **i18n**: English strings only (`en.yml`, `en.json` files); other languages come through Crowdin.
- **Test runs**:
  - Frontend: all 5,071 tests pass with `TZ=UTC` (CI's timezone). Locally, 17 date/time tests fail only because of the machine's timezone.
  - Backend: same pre-existing local-only failures as before (Slack upload redirect from the local `FRONTEND_URL`, and report-builder specs that fail only in a big batch).

## 5. Rollout

1. Deploy PR 1 → create markets in Settings → map each website's inbox (and any per-market WhatsApp inboxes) to its market; leave the shared email inbox unmapped → run the backfill (conversations from their inbox, then contacts from their most recent conversation with a market).
2. On every market website: pass the logged-in player's email via `setUser`, and turn on the pre-chat form with a required email for guests.
3. Head of Support builds the category tree in Settings before PR 5 goes live. Announce the "category required to resolve" rule to agents.
   Create the "Uncategorised resolved" saved view for team leads (filter: status = resolved, category is not present). If teams are by country, add the market → team automation rules (decision 4).
4. Track coverage: % of conversations resolved in the last 7 days with a market (watch the shared email inbox separately), and with a leaf category. Target ≥ 95% (PRD success measure). If system resolutions push coverage below target, revisit O1.

## 6. Acceptance criteria → where they are covered

| Acceptance criterion | Covered by |
|---|---|
| Market can be set and corrected manually, and appears on the conversation and in the list | §2 Markets update params; §3 sidebar panel, header chip, card badge |
| Filtering by market returns only that market; grouping shows counts per market | finder param + filter key; `group_counts` + sidebar Markets group |
| Each team has a view with accurate open and waiting counts | existing team route + `group_counts` (`group_by=team`) |
| A conversation can be moved between teams | already exists (team select in sidebar); Ticket 2 restricts who can do it |
| Admins can create, rename, reorder and remove categories without a release | categories API + Settings → Categories |
| Resolving without a category and subcategory is blocked in the API and explained in the UI | `ResolveGuard` (422) + `ResolveAction.vue` toast/focus |
| Categories, markets and team names are configuration, not code | all three are DB records edited in Settings |
