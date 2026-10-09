import Phaser from "phaser";
import { COLORS, GAME_HEIGHT, GAME_WIDTH, SCENES } from "../config";

export class MenuScene extends Phaser.Scene {
  constructor() {
    super(SCENES.menu);
  }

  create(): void {
    this.add
      .text(GAME_WIDTH / 2, GAME_HEIGHT / 2 - 40, "ETH EXAM RUN", {
        fontSize: "64px",
        color: COLORS.text,
        fontStyle: "bold",
      })
      .setOrigin(0.5);

    this.add
      .text(
        GAME_WIDTH / 2,
        GAME_HEIGHT / 2 + 30,
        "Dodge the exams, collect ECTS\nArrows / A D or touch to move",
        { fontSize: "22px", color: "#c8d3e6", align: "center" },
      )
      .setOrigin(0.5);

    const prompt = this.add
      .text(GAME_WIDTH / 2, GAME_HEIGHT - 80, "Press SPACE or tap to start", {
        fontSize: "26px",
        color: COLORS.text,
      })
      .setOrigin(0.5);

    this.tweens.add({ targets: prompt, alpha: 0.3, duration: 700, yoyo: true, repeat: -1 });

    const start = (): void => {
      this.scene.start(SCENES.game);
    };
    this.input.keyboard?.once("keydown-SPACE", start);
    this.input.once("pointerdown", start);
  }
}
