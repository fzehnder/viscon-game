import Phaser from "phaser";
import { COLORS, SCENES } from "../config";

// Loads assets. For now it generates placeholder textures in code,
// so nobody is blocked waiting for art. Replace with this.load.image(...) later.
export class BootScene extends Phaser.Scene {
  constructor() {
    super(SCENES.boot);
  }

  preload(): void {
    // Example for real assets (put files in public/assets/):
    // this.load.image("player", "assets/player.png");
  }

  create(): void {
    const g = this.make.graphics({ x: 0, y: 0 }, false);

    g.fillStyle(COLORS.ethBlue, 1);
    g.fillRect(0, 0, 40, 40);
    g.generateTexture("player", 40, 40);
    g.clear();

    g.fillStyle(COLORS.exam, 1);
    g.fillRect(0, 0, 36, 36);
    g.generateTexture("exam", 36, 36);
    g.clear();

    g.fillStyle(COLORS.credit, 1);
    g.fillCircle(12, 12, 12);
    g.generateTexture("credit", 24, 24);
    g.destroy();

    this.scene.start(SCENES.menu);
  }
}
