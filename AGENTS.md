# Cosmic Slayer

Retail WoW addon (Midnight, Interface 120100 / 120105). One folder, no libraries: `CosmicSlayer.toc` and `CosmicSlayer.lua`. Saved variables: `CosmicSlayerDB` in WTF, not in this repo.

The TOC version stays `1.0.0` until the first CurseForge publish. Do not bump it for local changes. See `PUBLISHING.md`.

## Goal

Notify the player when a Cosmic Slayer boss is the active Void Strike, so they can go get kill credit. Achievement id `62570`, 15 kills.

Watched names only:

- Void Ritual: Springclaw (Eversong, map `2395`)
- Void Ritual: Croaker (Eversong, map `2395`)
- Void Ritual: Grizzly (Zul'Aman, map `2437`)

These are rotating open-world strikes. One strike is active at a time, and only in that week's assault zone. The boss is part of that strike, not a separate spawn. Ritual Sites, Void Incursions, and other strikes are out of scope.

## What works

`C_AreaPoiInfo.GetEventsForMap(mapID)` then `GetAreaPOIInfo`. The `name` field is a normal string. Proven in game while Croaker was up: event `8723`, name `Void Ritual: Croaker`, on map `2395`.

Query by map id. Always scan both assault maps, plus the player's current map when it sits under one of them. The week-quest lookup only labels `this week`. It does not choose which map is scanned. A manual Refresh, or opening the panel, scans from anywhere. Automatic scans run on the saved poll interval, default 15 seconds and adjustable from 1 to 60, and on `AREA_POIS_UPDATED`, while the player is in Eversong Woods or Zul'Aman. Walk `C_Map.GetMapInfo` parents so a child map still counts. Entering that zone (`ZONE_CHANGED_NEW_AREA`) scans immediately.

Show a strike whose plain name or description contains `Void Ritual`, `Void Strike`, or a watched boss. Otherwise show one event whose name contains `Incursion`, and set the waypoint from that pin. Do not join unrelated map events into the strike line. A single `isCurrentEvent` name can still show when nothing else matched. If the name is a secret value, pass it to `SetText` and do not call string methods on it. The line under the strike is `Last refresh: HH:MM:SS`. Alert once per boss name until that name leaves the event list. Chat prefix is `CS`. `/cs` and `/cosmicslayer` toggle the panel.

## Week selection

Only one of Eversong or Zul'Aman has strikes each week. Prefer the map whose `C_TaskQuest.GetQuestsOnMap` list includes a title containing `Void Assaults:`. That list is the map task list, not the quest log. Seen id: `94385` Void Assaults: Eversong Woods. `Scan` calls `ActiveMap` so the header can say `this week`. Cache the chosen map for 10 minutes. The cache does not limit which map is scanned. If the title is missing, keep the previous week map. Never treat a failed lookup as "no strikes."

## Tests

From the repo root, `lua tests/scenarios.lua`. The harness fakes the WoW API and drives loading, entering a zone, the 2 second delay, the 15 second ticker, a strike spawning, a strike changing, leaving the zone, a secret strike name, and the waypoint check versus button. Keep `tests/scenarios.lua` out of the toc.

## Dead ends

Do not build detection on these. They were tried in game.

- `C_TaskQuest.GetQuestsForPlayerByMapID` is nil. Midnight name is `GetQuestsOnMap`. That list has world quests and the weekly assault quest, not the rotating strike.
- `C_VignetteInfo.GetVignettes` from Silvermoon returned the quartermaster, not the strike. `vig 1` means the scan was not looking at the strike.
- Monster say/yell from Imperator Pertinax is not the spawn signal. A listener on `CHAT_MSG_MONSTER_SAY` and `CHAT_MSG_MONSTER_YELL` printed nothing when Croaker was up.
- Silvermoon's displayed world state can differ from the live strike. Chat box `/run` lines must stay under 255 characters.
- Combat log, nameplates, and unit identity are the Midnight lockdown. This addon does not use them. Before calling string methods on API text, skip values where `issecretvalue` is true.

## UI settings

`CosmicSlayerDB`: `sound` (alert sound on or off), `alertSound` (which sound: raid warning, ready check, alarm, boss emote, or queue), `screen` (center-screen raid warning text), `chat`, `waypoint` (checkbox: auto user waypoint from the pin's `position` when a watched boss alerts), and `point` (panel position). The Set waypoint button marks the current strike immediately, preferring a watched boss when one is up. Defaults are all on. Progress text uses `GetAchievementInfo` / `GetAchievementCriteriaInfo` for achievement `62570`. Boss rows are grouped under Eversong Woods (Springclaw, Croaker) and Zul'Aman (Grizzly). The active week's header says `this week`. The panel opens expanded. `CosmicSlayerDB.collapsed` remembers a later collapse. Expanded uses a dark transparent backdrop (`0.06, 0.06, 0.06` at `0.78`) and a 1px black edge, the same idea as ElvUI's backdrop, built from `Interface\Buttons\WHITE8X8` rather than ElvUI's own media. Flat buttons replace the default gold button template. Collapsed is a borderless bar at `0.10` alpha with a light X that hides the panel and a two-line arrow that expands or collapses. Escape does not close the panel. Collapsed still shows achievement progress, the current strike, last refresh time, Refresh, and Set waypoint. A Settings button opens controls for frame alpha, background transparency, background color, font, font size, the poll interval, the screen alert, and the alert sound. The font control is a dropdown of every shipped game font that loads on this client, plus LibSharedMedia fonts when that library is installed. Each name is drawn in that font. Those values live in `CosmicSlayerDB`. Track achievement calls `C_ContentTracking.StartTracking` for `62570`. Clicking again stops tracking.

## Changing detection

Keep the three name substrings `Springclaw`, `Croaker`, and `Grizzly`. Match with plain `find` (the fourth argument `true`). A new source is acceptable only if a live `/run`, with that boss up, prints the boss name as a normal string. Paste that output into the commit or this file before replacing `GetEventsForMap`.
