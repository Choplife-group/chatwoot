# Implementation plan: Role-aware inbox access and VIP flagging

Ticket 2 of the Support Tool PRD. Codebase: this repo (Chatwoot 4.18, **Community Edition** build). Builds on Ticket 1 (`docs/inbox_organization_plan.md`).

Status: **All 6 PRs done on branch `feat/role-access-vip`, not committed or deployed. The open points below still use their defaults, and the flag is off by default.**

## Constraints that shape the design

- **CE only.** `enterprise/` is deleted in CI, so upstream's custom roles (`custom_role_id`, `conversation_manage` permissions) are not available. `AccountUser` has two roles: `agent` and `administrator`.
- **Test as CE.** Run dev and specs with `DISABLE_ENTERPRISE=true`, because `enterprise/` still overrides `PermissionFilterService` and `ConversationPolicy` locally.
- **Upstream merges.** Keep edits to upstream files small. Prefer one shared rule over checks spread across files.
- **Visibility is not one place today.** `Conversations::PermissionFilterService` covers most lists, but several paths skip it (see section 2). Changing the service alone would leak.

## Decisions

1. **Head of Support = the existing `administrator` role.** No new role. Admins already see everything. Adding a third value to the `role` enum would touch every permission check in the app for no gain.
2. **Team lead = a flag on team membership** (`team_members.lead`), not an account role. A person can lead one team and not another, and it needs no change to the role enum. A lead must be a member of the team.
3. **One visibility rule.** `PermissionFilterService` holds it. `ConversationPolicy#show?`, search, realtime and notifications all use it or its audience equivalent, so they can't drift apart.
   - Administrator: everything.
   - Team lead: conversations of the teams they lead, plus conversations assigned to them.
   - Agent: conversations assigned to them.
   - Team-based access doesn't depend on inbox membership, so leads don't need adding to every inbox.
4. **VIP is a column (`conversations.vip`), not a label.** Labels can be changed through the labels API, bulk actions, macros and automations, so protecting one means guarding every path. A column has one write path: a dedicated endpoint with one policy check.
5. **Rules apply to people, not the system.** Auto-assignment, automation rules and bots can still assign. Same approach as `Conversations::ResolveGuard` in Ticket 1.
6. **Agents can't assign, reassign or change team.** This replaces Ticket 1's "any agent can move a conversation between teams". Agents keep replying, resolving, setting category and market, and labels.
7. **Leads assign within their own team**, and can send a conversation to another team. It arrives there unassigned and leaves their view.
8. **An agent who starts an outbound conversation becomes its assignee**, otherwise they couldn't see what they just created.
9. **Account feature flag `restricted_inbox_access`.** Off by default. Deploy first, set up leads and routing, then turn it on per account. It's also the rollback switch: turning it off restores today's visibility with no deploy.
10. **VIPs sort first.** VIP conversations sit at the top of every list, then the chosen sort applies. Plus a highlighted card and badge.

## Open points (recommended default in place until answered)

| # | Question | Default |
|---|---|---|
| O1 | Can an agent be brought into someone else's conversation by @mention or as a participant? | **No.** The ticket says agents see only their own. Mentions of an agent with no access send no notification, and the mention list offers only people who can see the conversation. A lead reassigns if help is needed |
| O2 | Who handles conversations with no team? | **Head of Support only**, so every market needs a routing rule (Ticket 1 automation) before the flag goes on |
| O3 | Is VIP per conversation or per player? | **Per conversation**, as the ticket says. Many support tools mark the player so future chats are VIP too. That's a small add-on if wanted |
| O4 | Should agents still see all contacts (name, email, phone)? | **Yes, unchanged.** The ticket covers conversations. Contact lists and contact search stay account-wide, and the conversations shown on a contact are filtered. Restricting contacts is a separate decision |

## Inputs needed from the support team

- Who leads each team, and who is the Head of Support (or Heads).
- Which agents belong to which team.
- A team and routing rule per market (Ticket 1 config, not created yet on dev or production).
- Who counts as VIP, so leads apply the tag consistently.

## 1. Data model

- `team_members.lead` (boolean, default false, not null).
- `conversations.vip` (boolean, default false, not null). Adding a column with a constant default doesn't rewrite the table.
- Index for the sort and filter: `(account_id, vip)` partial `WHERE vip`, built `concurrently`. VIPs are rare, so it stays small.
- No foreign keys, per repo rule.

## 2. Backend: visibility

**Already covered by `PermissionFilterService`:** conversation list and meta (`ConversationFinder`), advanced filter (`FilterService`), contact and company conversations, contact attachments, group counts (Ticket 1 sidebar), bulk actions, `filter_query_counter`, `filtered_counter`.

**Not covered, must change:**

| Path | Today | Change |
|---|---|---|
| `ConversationPolicy#show?` | Inbox or team member. Every `/conversations/:id/...` route depends on it, including messages | Use the same rule as the filter service |
| `SearchService#filter_conversations` | Inbox ids only | Go through the filter service |
| `SearchService` message search | Inbox ids; `should_skip_inbox_filtering?` skips the check for anyone who has all inboxes | Limit to visible conversation ids |
| `ActionCableListener` | Broadcasts messages and conversations to all `inbox.members` | Broadcast to the conversation's audience |
| `NotificationListener` | Notifies all `inbox.members` on new conversations | Same audience |
| Unread counts (`Builder`, Redis memberships) | Keyed on inbox, assignee, team | Confirm the counts honour the new rule. Also invalidate when `team_members.lead` changes, as `TeamMember` only does this on create and destroy today |
| Linear and Dyte integration controllers | Look up conversations directly | Confirm they authorize; add it if not |

**New `Conversations::AudienceService`:** returns assignee + leads of the conversation's team + administrators. With the flag off it returns inbox members, as today.

**Reassignment:** the agent who loses a conversation must receive an event so it disappears from their list immediately. `assignee_changed` and `team_changed` also go to the previous assignee.

## 3. Backend: assignment rules

One rule, `ConversationPolicy#assign?`, true for administrators and leads of the conversation's team. Enforced at each entry point a person can use:

- `Conversations::AssignmentsController#create` (assignee and team).
- `BulkActionsController` and `BulkActionsJob` (`assignee_id`, `team_id` fields; skipped ids returned as with the resolve guard).
- `ConversationsController#create` (`assignee_id`, `team_id` params; see decision 8).
- `Macros::ExecutionService` (`assign_agent`, `assign_team`, skipped with an activity note).

The lead's assignee list in Conversation Actions comes from the team's members. `AssignableAgentsController` is unchanged.

## 4. Backend: VIP

- `POST /api/v1/accounts/:id/conversations/:id/vip` with `{ vip: true|false }`, authorized by `ConversationPolicy#update_vip?` (administrators and leads of the conversation's team). An agent gets `401`.
- `vip` is not accepted by any other write path.
- Activity message when it changes.
- `vip` in `push_event_data` and the conversation jbuilder.
- `vip` in `filter_keys.yml`, for the advanced filter.
- Sort prefix in `ConversationFinder` and `FilterService`.
- Swagger updated.

## 5. Frontend (Vue 3, `<script setup>`, Tailwind only, i18n for all strings)

- **Settings → Teams:** a "Team lead" toggle per member.
- **User payload:** `led_team_ids`, plus a getter for "can assign this conversation".
- **List tabs:** agents see Mine only. Unassigned and All stay for leads and admins (`ASSIGNEE_TYPE_TAB_PERMISSIONS`).
- **Conversation Actions:** assignee and team pickers are read-only for agents. Bulk assign is hidden.
- **VIP:** badge on the card and in the conversation header, highlighted card, and a toggle for leads and admins only. VIP in the filter dropdown and matcher (`filterHelpers.js`, the gap we hit in Ticket 1).
- **Client-side sort:** the store's list sort must also put VIPs first, or live updates reorder the list wrongly.
- **Realtime:** drop a conversation from the store when the user loses access.
- **Mentions:** limit the list per O1.

## 6. Delivery plan (separate PRs)

| PR | Scope | Estimate | Status |
|---|---|---|---|
| 1 | Team leads: migration, API, Settings → Teams, user payload | 1–2 d | ✅ Done (not committed) |
| 2 | Visibility: flag, filter service, policy, search | 2–3 d | ✅ Done (not committed) |
| 3 | Realtime, notifications, unread counts, audience service | 3 d | ✅ Done (not committed) |
| 4 | Assignment rules on all four entry points, picker changes, list tabs | 2–3 d | ✅ Done (not committed) |
| 5 | VIP: migration, endpoint, filter, sort, badge, toggle | 2–3 d | ✅ Done (not committed) |
| 6 | Mentions, full role-by-role test pass, docs | 1–2 d | ✅ Done (not committed) |

**Each PR is safe to deploy alone because the flag stays off.** PRs 2 and 3 must both be in before the flag goes on anywhere: PR 2 alone blocks the page, but realtime would still send message content to every inbox member.

### Progress log

**PR 1: Team leads**

- Migration `20261105100000_add_lead_to_team_members`: `team_members.lead`, boolean, default false.
- `TeamMember.leads` scope. Changing `lead` invalidates the filtered unread counts, ready for PR 3.
- `PATCH /teams/:id/team_members` takes an optional `lead_ids`, which must be a subset of `user_ids`, otherwise `422`. Leaving it out keeps the current leads, so older clients are unaffected. Admins only, as before.
- Team member responses include `lead`. The user payload has `led_team_ids` per account.
- Settings → Teams → Edit → agents has a Team lead toggle. It's disabled for people who aren't ticked, and unticking someone clears it.
- Fixed `teamMembers/update` in the store, which saved the response without its `teamId`.
- Lead status doesn't change what anyone can see yet. That's PR 2.
- Swagger rebuilt. Specs added for the API, the model and the profile payload.

**PR 2: Visibility**

- New account feature `restricted_inbox_access` in `config/features.yml`, off by default. Turn it on per account in Super Admin → Accounts.
- `PermissionFilterService`: with the flag on, agents get conversations assigned to them; team leads also get the teams they lead, whatever their inbox membership. Administrators are unchanged. With the flag off, nothing changes.
- `ConversationPolicy#show?` uses the same rule, which covers every `/conversations/:id/...` route, including messages.
- `SearchService`: conversation search goes through the filter service; message search is limited to visible conversations, which also closes the skip for people who have every inbox.
- `Integrations::LinearController` had no access check on conversations, so it now authorizes. This applies with the flag off too: an agent outside the inbox can no longer read or change a conversation's Linear links.
- Dyte already authorizes. The direct upload controller doesn't, but it only stores a file and returns nothing from the conversation, so it's unchanged.
- Checked on the running app as agent, lead and admin: list, counts, opening a conversation, messages and both searches all matched the rule. A direct URL to someone else's conversation shows nothing in the dashboard.

**PR 3: Realtime, notifications, unread counts**

- New `Conversations::AudienceService`: assignee and leads of the conversation's team with the flag on, inbox members with it off. Administrators are added by the caller, as before.
- `ActionCableListener` uses it for every conversation and message event, including typing.
- New `conversation.access_removed` event carries only the conversation id, to anyone who lost access on an assignee or team change. The dashboard drops it from the list and closes it if it's open.
- Gaining access needs nothing new: the existing update event adds the conversation to the list.
- Notifications needed no listener change. `NotificationBuilder` already checks `ConversationPolicy#show?`, so PR 2 covers them, including mentions and participants.
- `MentionService` uses the audience, so an agent who can't see a conversation can't be mentioned on it (O1). This moved here from PR 6 because a mention sends the conversation's data to that person. PR 6 keeps only the dashboard's mention list.
- Unread counts: the Redis store is keyed by inbox, team and assignee and can't hold "mine plus my team's" without double counting, so `RestrictedCounter` reads the database for agents and leads. Administrators stay on Redis. `Conversations::UnreadCounts::Builder#unread_conversations` is now public for this.
- `conversation.unread_count_changed` still goes to inbox members. Its payload is empty, it only asks the dashboard to refetch, so it reveals nothing.
- Checked live on the running app as an agent, with no reload: a conversation reassigned away closed and left the list, one assigned to them appeared, and sidebar counts followed.

**PR 4: Assignment rules**

- New `Conversations::AssignmentGuard`, the one place for the rule. `ConversationPolicy#assign?` uses it.
- `AssignmentsController`: agents get `401`. A lead can act only in teams they lead, and an assignee outside the team gets `422`. Unassigning and moving to another team are allowed.
- `BulkActionsJob`: drops the assignee and team changes it isn't allowed to make, and still applies the rest.
- `Macros::ExecutionService`: skips `assign_agent`, `assign_team` and `remove_assigned_team`, and leaves an activity note.
- `ConversationsController#create`: a restricted user becomes the assignee (decision 8), and a team is kept only if they lead it. It also authorizes the result, because an inbox locked to a single conversation returns the existing one, which could be someone else's.
- Dashboard (`useConversationAccess`): agents see the Mine tab only, assignee and team as plain text, and no assign options in the context menu, bulk actions, command bar or reply banner.
- **Known limit:** the context menu and bulk assign lists still use the inbox's assignable agents. A lead who isn't in the inbox gets an empty list there and must use Conversation Actions. Add leads to their inboxes, or extend `AssignableAgentsController`, if this matters in practice.
- Checked on the running app: agent `401` on assign and team change, lead `200` in their team and `401` on another team, admin `200`. Agent and lead views checked in the browser.

**PR 5: VIP**

- Migrations `20261105120000_add_vip_to_conversations` (`conversations.vip`, boolean, default false) and `20261105120001_add_conversation_vip_index` (partial index on `(account_id, vip) WHERE vip`, built `concurrently`).
- `POST /conversations/:id/vip` with `{ vip: true|false }`, the only write path. `ConversationPolicy#update_vip?` allows administrators and leads of the conversation's team. Anything but a boolean gets `422`.
- **The VIP rules don't depend on `restricted_inbox_access`.** Only leads and admins can change VIP, with the flag on or off.
- `VipHandler`: activity message when it changes. `vip` is in the list payload and `push_event_data`, and in the keys that trigger `conversation.updated`, so changes show live.
- `Conversations::SortService` sorts VIP first for every sort option. `sortComparator` does the same in the store, so live updates don't reorder the list wrongly.
- Filter: `vip` in `filter_keys.yml`, both dashboard filter lists, and the client-side matcher. The finder param in the first draft wasn't needed, as nothing would have used it.
- Dashboard: VIP badge on the card and conversation header, amber highlight on the card, and a VIP toggle for leads and admins only, in Conversation Actions and in the card's right-click menu (Mark as VIP / Remove VIP).
- Swagger updated.
- Checked on the running app: a lead turned on VIP and the conversation moved to the top with its badge and activity line. Agent `401`, including on their own conversation; `vip` on the update endpoint is ignored; lead of another team `401`; admin `200`; the filter returned only VIP conversations the user can see.

**PR 6: Mentions and full test pass**

- `TagAgents`: with the flag on, the mention list offers only administrators, the assignee and the leads of the conversation's team. This applies to admins writing a note too. Team mentions are hidden, as a team mention reaches members who can't see the conversation. The server already enforces this (PR 3).
- `useConversationAccess` also exposes `isAccountRestricted`, for lists that depend on the account rather than the current user.
- **Known limit:** the participants panel still lets someone add a watcher who can't see the conversation. It gives them no access or notifications, so nothing leaks, but it does nothing useful with the flag on.
- Role-by-role check on the running app with the flag on, one conversation per case (assigned to the agent, in the lead's team, in another team, no team):

| Check | Agent | Lead | Admin |
|---|---|---|---|
| List | #1 | #1, #6 | All four |
| Open a conversation | #1 | #1, #6 | All four |
| Search conversations and messages | #1 | #1, #6 | All four, within the first page of results |
| Change assignee or team | `401` | Own team only | Yes |
| Add or remove VIP | `401` | Own team only | Yes |
| VIP filter | Own conversations only | Team's | All |

- Unread counts returned `200` for every role, but the test data had nothing unread, so their numbers are covered by `counter_spec`, not this run.
- Full suites: frontend 5,079 tests pass. Backend 7,348 examples, 16 failures: 1 was ours (`account_spec` feature flag list, fixed). The other 15 aren't from this work:
  - 10 in `confirmation_instructions_spec`: an `enterprise/` view is on disk while `DISABLE_ENTERPRISE=true` is set. All 11 examples pass with enterprise loaded.
  - 4 in `slack_uploads_controller_spec`: the local `FRONTEND_URL=http://0.0.0.0:3000`.
  - 1 in `agent_builder_spec`: seen before this ticket, in large batch runs.
- `spec/enterprise` wasn't run, as it doesn't apply to the CE build.

## 7. Rollout

1. Deploy with the flag off.
2. Create teams per market, add agents, mark leads, add routing rules.
3. Confirm inboxes have auto-assignment on. Without it, new conversations reach leads but no agent.
4. Assign existing open conversations, or agents will lose sight of them when the flag goes on.
5. Turn the flag on for dev, test with one account of each role, then production.

## 8. Risks

- **Conversations nobody works.** Unassigned conversations are invisible to agents. If auto-assignment is off, or a team's agents are offline, they wait for the lead. No team means only the Head of Support sees them.
- **Leaks through missed paths.** The specs must check every path in section 2 as an agent, not only the list.
- **List performance.** The filter moves from inbox to assignee and team, which are already indexed, so it should be lighter. Check on production-sized data, especially message search.
- **Agents who leave.** Their conversations become unassigned and go to the lead.
- **Upstream merges.** `ActionCableListener` and `SearchService` change often upstream, so keep edits there to a single call.

## 9. Acceptance criteria → where they are covered

| Criterion | Covered by |
|---|---|
| An agent's inbox, unread counts and search contain only their own conversations | PRs 2, 3 |
| A team lead sees their team's full queue and no other team's conversations | PRs 1, 2 |
| The Head of Support sees everything | Decision 1, PR 2 |
| Only leads and above can change assignee or team | PR 4 |
| VIP conversations are distinguishable and filterable | PR 5 |
| An agent adding or removing VIP is rejected by the API | PR 5 |
