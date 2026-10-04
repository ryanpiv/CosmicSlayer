# Cosmic Slayer

Retail WoW addon (Midnight, Interface 120100 / 120105). One folder, no libraries: `CosmicSlayer.toc` and `CosmicSlayer.lua`. Saved variables: `CosmicSlayerDB` in WTF, not in this repo.

## Goal

Notify the player when a Cosmic Slayer boss is the active Void Strike, so they can go get kill credit. Achievement id `62570`, 15 kills.

Watched names only:

- Void Ritual: Springclaw (Eversong, map `2395`)
- Void Ritual: Croaker (Eversong, map `2395`)
- Void Ritual: Grizzly (Zul'Aman, map `2437`)

These are rotating open-world strikes. One strike is active at a time, and only in that week's assault zone. The boss is part of that strike, not a separate spawn. Ritual Sites, Void Incursions, and other strikes are out of scope.

## What works

`C_AreaPoiInfo.GetEventsForMap(mapID)` then `GetAreaPOIInfo`. The `name` field is a normal string. Proven in game while Croaker was up: event `8723`, name `Void Ritual: Croaker`, on map `2395`.

Query by map id. Do not require the player to be standing in the zone. Poll about every 10 seconds plus `AREA_POIS_UPDATED`. Alert once per boss name until that name leaves the event list. Chat prefix is `CS`. `/cs` and `/cosmicslayer` toggle the panel.

## Week selection

Only one of Eversong or Zul'Aman has strikes each week. Prefer the map whose `C_TaskQuest.GetQuestsOnMap` list includes a title containing `Void Assaults:`. That list is the map task list, not the quest log. Seen id: `94385` Void Assaults: Eversong Woods. Cache the chosen map for 10 minutes. If the title is missing, scan both maps. Never treat a failed lookup as "no strikes."

## Dead ends

Do not build detection on these. They were tried in game.

- `C_TaskQuest.GetQuestsForPlayerByMapID` is nil. Midnight name is `GetQuestsOnMap`. That list has world quests and the weekly assault quest, not the rotating strike.
- `C_VignetteInfo.GetVignettes` from Silvermoon returned the quartermaster, not the strike. `vig 1` means the scan was not looking at the strike.
- Monster say/yell from Imperator Pertinax is not the spawn signal. A listener on `CHAT_MSG_MONSTER_SAY` and `CHAT_MSG_MONSTER_YELL` printed nothing when Croaker was up.
- Silvermoon's displayed world state can differ from the live strike. Chat box `/run` lines must stay under 255 characters.
- Combat log, nameplates, and unit identity are the Midnight lockdown. This addon does not use them. Before calling string methods on API text, skip values where `issecretvalue` is true.

## UI settings

`CosmicSlayerDB`: `sound` (raid warning), `chat`, `waypoint` (user waypoint from the pin's `position`), and `point` (panel position). Defaults are all on. Progress text uses `GetAchievementInfo` / `GetAchievementCriteriaInfo` for achievement `62570`.

## Changing detection

Keep the three name substrings `Springclaw`, `Croaker`, and `Grizzly`. Match with plain `find` (the fourth argument `true`). A new source is acceptable only if a live `/run`, with that boss up, prints the boss name as a normal string. Paste that output into the commit or this file before replacing `GetEventsForMap`.
