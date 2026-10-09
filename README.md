# VISCON Hackathon Game

2D browser game built with Phaser 3, TypeScript and Vite. Current placeholder: **ETH Exam Run** (dodge exams, collect ECTS). Swap in the real idea whenever the team decides.

## Run it

Requires Node 20+.

```bash
npm install
npm run dev        # http://localhost:5173, hot reload
npm run build      # type check + production build into dist/
npm run preview    # serve the production build locally
```

## Project layout

```
src/
  main.ts            game config, scene list
  config.ts          sizes, colors, scene keys (shared constants)
  scenes/            one file per scene (Boot, Menu, Game, GameOver)
public/assets/       images, audio, fonts (served as-is, load with "assets/<file>")
docs/TEAM.md         roles, timeline, git workflow
.github/workflows/   auto-deploy to GitHub Pages on push to main
```

## Adding a scene

1. Create `src/scenes/MyScene.ts` extending `Phaser.Scene` with a unique key in `SCENES` (`config.ts`).
2. Add it to the `scene: [...]` array in `src/main.ts`.
3. Start it from another scene with `this.scene.start(SCENES.myScene)`.

## Adding assets

Drop files in `public/assets/`, load them in `BootScene.preload()`:

```ts
this.load.image("player", "assets/player.png");
this.load.audio("jump", "assets/jump.mp3");
```

Until real art exists, `BootScene.create()` generates colored placeholder textures, so nobody waits on anybody.

## Deploying

Pushing to `main` runs `.github/workflows/deploy.yml`, which builds and publishes to GitHub Pages.
Note: Pages from a **private** repo needs a paid GitHub plan. On a free plan, make the repo public for the demo, or deploy `dist/` to Netlify or Vercel instead.
One-time setup: repo Settings, Pages, Source = GitHub Actions.
