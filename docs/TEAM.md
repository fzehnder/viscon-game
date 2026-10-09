# Team plan (5 people, 42h)

Clock: start Fri 09 Oct 18:55, end Sun 11 Oct 12:55 (Zurich time). Aim to be submission-ready by Sun 11:00.

## Roles (swap freely, but keep one owner per area)

| # | Area | Owns | Main files |
|---|------|------|-----------|
| 1 | Core gameplay | Player, controls, physics, win/lose rules | `src/scenes/GameScene.ts` |
| 2 | Content / level design | Levels, enemies, difficulty curve, ETH references | new files in `src/levels/` |
| 3 | Art / UI | Sprites, backgrounds, menus, HUD, fonts | `public/assets/`, `MenuScene.ts` |
| 4 | Audio / game feel | Music, sfx, particles, screen shake, animations | new files in `src/fx/` |
| 5 | Integration / pitch | Merging PRs, deploy, bugs, demo video, slides | `README.md`, `.github/`, `docs/` |

Everyone: fix bugs you see, but tell the owner before touching their file.

## Timeline

| When | Milestone |
|------|-----------|
| Fri 19:00 to 21:00 | Pick the game idea, run the repo locally, everyone pushes one tiny change |
| Fri 21:00 to Sat 01:00 | Core loop playable (move, score, lose). Then sleep in shifts |
| Sat 19:00 (hour ~24) | **Playable build** with real art and sound started |
| Sun 06:00 | **Feature freeze**. Only bug fixes and polish after this |
| Sun 09:00 | Demo video / pitch recorded, deployed build checked on a second device |
| Sun 11:00 | Final submission buffer. Nothing new merges after this |

## Git workflow

- `main` always runs. Never push broken code to it.
- One branch per person per task: `name/short-topic` (e.g. `finn/player-movement`).
- Small commits, pull before you push: `git pull --rebase origin main`.
- Merge via pull request, one quick review from the integrator, squash merge.
- Binary assets (images, audio) conflict badly. Only the art and audio owners edit existing files, others add new ones.
- Commit messages: short and plain, e.g. `Add exam spawn rate scaling`.

## Demo checklist

- [ ] Game starts in under 5 seconds on a fresh browser tab
- [ ] Works with keyboard and touch
- [ ] Has a clear goal within the first 10 seconds
- [ ] Deployed link works on a phone
- [ ] Backup: screen recording of a full run
