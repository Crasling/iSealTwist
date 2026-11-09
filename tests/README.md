# iST timing checks

Run `unsealed_wrath.lua` from the addon directory. It checks seal casts and
countdowns, stack cues, parry haste, previews, and restricted-value guards using
the real addon files and a simulated clock.

Wrath checks include readable combat counts with hidden expiry or instance IDs,
added/updated aura payloads, cached instances, immediate cue updates, and delayed
post-swing correction. Counts and expiry estimates are tracked separately; hidden
counts remain estimates. Follow-up reads are coalesced and cancelled on death or
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
It is an estimate from those captures, not a measurement of the current client
or an offset learned automatically by iST.

Reference: [LibClassicSwingTimerAPI's capture findings](https://github.com/Ralgathor/LibClassicSwingTimerAPI/blob/main/docs/FOREVER_API_FINDINGS.md#L1594).

For a live check, enable Debug Mode and capture the parry lines together with
the next main-hand swing. iST logs the before/after prediction and the next
observed swing's difference from both the corrected and original deadlines.
A negative difference means the swing arrived early; a positive one means late.
Speed changes or swing-resetting casts cancel that comparison. The simulated
checks do not establish event delivery timing on a live server.
