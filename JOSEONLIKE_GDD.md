# JOSEONLIKE

## Game Design Document (GDD)

Version: 0.1

------------------------------------------------------------------------

# 1. Project Overview

## Project Name

JOSEONLIKE

## Genre

Pixel Art Roguelike Survival Action RPG

## Platform

-   Android
-   iOS
-   PC (Steam)

## Business Model

Free-to-play with advertisement monetization.

------------------------------------------------------------------------

# 2. Game Concept

A Joseon-inspired pixel roguelike survival game where various hunters
fight against spirits, monsters, and forgotten creatures.

Core keywords: - Korean folklore - Joseon fantasy - Roguelike - Auto
combat - Character collection - Weapon evolution - Pixel art

------------------------------------------------------------------------

# 3. Core Direction

The game does not focus on a single hero.

Players choose different hunters with unique combat styles.

Characters: - Taoist - Warrior - Archer - Assassin - Shaman - Monk -
Hunter

------------------------------------------------------------------------

# 4. World Setting

A fictional Joseon era.

As people gradually forget old legends and beliefs, forgotten spirits
begin appearing.

The balance between humans and spirits collapses, causing supernatural
incidents.

------------------------------------------------------------------------

# 5. Gameplay Loop

Base Camp ↓ Select Character ↓ Select Area ↓ Enter Stage ↓ Auto Combat ↓
Collect Experience ↓ Choose Upgrade ↓ Defeat Boss ↓ Acquire Rewards ↓
Upgrade Base ↓ Unlock Content

------------------------------------------------------------------------

# 6. Combat System

Inspired by Vampire Survivors style.

Presentation (revised 2026-08-14): side-view pixel art. Characters and
monsters face left or right only — no 8-direction rotations. Facing follows
the horizontal component of movement; pure vertical movement keeps the last
facing. Left is an in-engine horizontal mirror of the right-facing sprite.
Walking plays a 4-frame walk cycle. Style anchor: `new_asset/basic.png`.

Player: - Movement only

Combat: - Automatic attacks

Growth: - Weapon upgrades - Passive abilities - Skill selection -
Evolution system

------------------------------------------------------------------------

# 7. Character System

Weapon identity rule (revised 2026-08-14): every character declares its
allowed weapon categories in `data/characters.json` (`weapon_categories`).
A character can only be offered and equip weapons whose category is in that
list — a Taoist can never wield a sword. The starting weapon is fixed per
character and must belong to an allowed category. Passives are shared by all
characters.

## Taoist

Role: - Magic damage - Area damage - Status effects

Allowed categories: - Spiritual

Weapon: - Talisman

Examples: Old Talisman → Fire Talisman → Five Elements Talisman → Divine
Seal

------------------------------------------------------------------------

## Warrior

Role: - Melee combat - High damage - Defense

Allowed categories: - Melee

Weapon: - Sword

------------------------------------------------------------------------

## Archer

Role: - Long range damage

Allowed categories: - Ranged

Weapons: - Bow - Korean Bow - Fire Arrow

------------------------------------------------------------------------

## Firearm Hunter

Role: - Slow but powerful attacks

Allowed categories: - Ranged

Weapons: - Matchlock - Improved Matchlock

------------------------------------------------------------------------

## Assassin

Role: - Critical damage - Evasion

Allowed categories: - Melee - Ranged

Weapons: - Throwing Knife - Poison Weapon

------------------------------------------------------------------------

# 8. Weapon System

Categories:

## Melee

-   Sword
-   Spear
-   Dual Sword
-   Axe

## Ranged

-   Bow
-   Matchlock
-   Throwing Weapons

## Spiritual

-   Talisman
-   Magic
-   Summons

------------------------------------------------------------------------

# 9. Weapon Grade System

Grades:

Common → Rare → Epic → Legendary → Mythic

Higher grades provide: - Higher damage - Additional effects - Unique
visuals - Special abilities

------------------------------------------------------------------------

# 10. Level Up System

Each level provides random choices.

Example:

Level 10:

1.  Upgrade Fire Talisman
2.  Acquire Spirit Flame
3.  Increase Attack Speed

------------------------------------------------------------------------

# 11. Passive System

Passive abilities: - Attack Damage - Attack Speed - Movement Speed -
Critical Chance - HP - Experience Gain - Luck - Skill Power

------------------------------------------------------------------------

# 12. Weapon Evolution

Examples:

Fire Talisman + Magic Power = Phoenix Talisman

Bow + Attack Speed = Divine Bow

Poison Knife + Critical Chance = Hundred Poison Blade

------------------------------------------------------------------------

# 13. Base Camp System

Hunter Base

Buildings: - Workshop - Archive - Training Ground - Shrine

------------------------------------------------------------------------

# 14. Stage System

Initial areas:

## Bamboo Forest

-   Goblins
-   Forest spirits

## Abandoned Temple

-   Ghosts
-   Cursed spirits

Future: - Capital City - Royal Tomb - Spirit World

------------------------------------------------------------------------

# 15. Quest and Achievement System

Quests: - Daily quests - Story quests

Achievements: - First Boss Clear - Monster Collection - Weapon Master

------------------------------------------------------------------------

# 16. MVP Scope

Characters: - Taoist - Warrior - Archer

Areas: - Bamboo Forest - Abandoned Temple

Content: - 20 Weapons - 15 Monsters - 3 Bosses - 50 Achievements

------------------------------------------------------------------------

# 17. Development Principles

1.  Mobile-first design
2.  10\~15 minute sessions
3.  High replay value
4.  Easy content expansion
5.  Data-driven structure
6.  Consistent pixel art style
