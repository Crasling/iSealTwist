# iST timing checks

The settings checks also cover page titles and summaries, selected navigation,
circle-handle dragging, wheel scrolling, per-page scroll positions, dropdown
dismissal, disabled controls, and cleanup when the window closes.

## Hit-based Wrath tracking

Real and Fake talent modes use the same tracking. A main-hand swing queues an
attempt; matching physical target feedback adds or releases stacks on WOUND.
MISS, DODGE, and PARRY leave stacks and their deadline unchanged. Glancing and
partially blocked WOUND results still count. Damage amounts are never inspected.
Extra target feedback cannot add another stack without another player swing.
Readable buff counts take precedence and cannot be followed by an extra
synthetic stack for the same attack.

The matching window is 0.30–1.20 seconds after the swing. It covers the observed
0.43–0.57-second feedback and the 0.99-second Command case in the build 70862
captures. Target changes, seal changes, expiry, overlapping swing windows, and
unknown player casts invalidate ambiguous matches. A timeout never awards a stack.
Known seal casts/procs do not invalidate a pending match. Holy Strike and Judgement's Holy
damage is ignored while a later physical hit may still count. Avoidance feedback
during that overlap leaves the attempt pending because an avoided Holy Strike
can also report school 1; without a usable hit, it times out without a stack.
UNIT_COMBAT does not identify the attacker: other attackers or unusual delivery
delays can still produce incorrect matches. Group combat needs further live testing.

Run hit_tracking.lua for the captured Command sequence (1, 1, 2, 3), avoided
replacement swings, expiry, duplicate feedback, secret metadata, target changes,
cast interference, Holy Strike/Judgement overlap, and readable-aura precedence. The unsealed_wrath.lua checks
also dispatch real swing/feedback events through Main and exercise the cue renderer.
Normal Debug Mode explains matched, avoided, skipped, and timed-out attempts.

## Live hit recorder

The hit recorder loads idle from iSealTwist_HitDebug.lua. Run `/ist hitdebug
start 60` to capture a fight, `/ist hitdebug mark <note>` to mark an observed
stack count, and `/ist hitdebug show` to copy the report. Stop and clear are
also available. Captures stop automatically after 10 to 180 seconds and keep
the newest 1,000 rows in this character's settings. Restricted values are
saved only as `<secret>`. The report records group context, player swings,
target feedback, stack decisions, and any matching public Echo or Windfury
auras. It does no polling before a capture starts.

Run hit_debug.lua from the addon directory to check secret handling, timing,
capture bounds, automatic shutdown, reload persistence, and the copy window.

## Simulated tracking checks

Run `unsealed_wrath.lua` from the addon directory. It checks seal casts and
countdowns, stack cues, parry haste, previews, and restricted-value guards using
the real addon files and a simulated clock.

Wrath checks include readable combat counts with hidden expiry or instance IDs,
added/updated aura payloads, cached instances, immediate cue updates, and delayed
post-swing correction. Count and expiry confirmation are tracked separately;
hidden counts continue through hit tracking. Follow-up reads are coalesced and cancelled on death or
tracking-mode changes so aura traffic cannot create an unbounded timer queue.

It also checks both seal-pair modes and the standalone seal and Righteous Fury
reminders: missing/expiring buffs, independent thresholds, permanent buffs,
dragging, scale, previews, and the Protection-only filter. Protection uses the
applied points returned by the Forever specialization API, not talent previews.
Combat reloads wait for a safe talent read; restricted aura values are ignored.
Fury keeps its confirmed expiry through empty combat-entry reads, restricted
lookups, and split removal/replacement updates. Cached aura instances and complete
out-of-combat buff scans recover missed updates. Clearing a live buff requires
confirmed removal after a short replacement check, or two complete absence scans.
The one-second recovery checks do not restart the duration. Debug messages record
which source confirmed the buff or marked it missing.

The parry checks first exercise the 40% reduction and 20% floor without dispatch
delay. They then use the production event offset with a 2.6-second weapon,
including a delayed parry arriving after the next swing has begun. Such an event
must not speed up that newer swing. Other cases cover the next deadline already
being due, repeated parries, real speed changes, and spell resets.

## Event timing reference and live verification

The 0.65-second offset comes from external captures on Forever build 70124,
with 2.4- and 3.4-second weapons. It aligns the defensive `UNIT_COMBAT` parry
notification with the `PLAYER_SWING` timer before applying the parry bands.
It is derived from those captures, not a measurement of the current client
or an offset learned automatically by iST.

Reference: [LibClassicSwingTimerAPI's capture findings](https://github.com/Ralgathor/LibClassicSwingTimerAPI/blob/main/docs/FOREVER_API_FINDINGS.md#L1594).

For a live check, enable Debug Mode and capture the parry lines together with
the next main-hand swing. iST logs the before/after prediction and the next
observed swing's difference from both the corrected and original deadlines.
A negative difference means the swing arrived early; a positive one means late.
Speed changes or swing-resetting casts cancel that comparison. The simulated
checks do not establish event delivery timing on a live server.
