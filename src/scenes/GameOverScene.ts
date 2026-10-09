import Phaser from "phaser";
import { COLORS, GAME_HEIGHT, GAME_WIDTH, SCENES } from "../config";

export class GameOverScene extends Phaser.Scene {
  private finalScore = 0;

  constructor() {
    super(SCENES.gameOver);
  }

  init(data: { score?: number }): void {
    this.finalScore = data.score ?? 0;
  }

  create(): void {
    this.add
      .text(GAME_WIDTH / 2, GAME_HEIGHT / 2 - 40, "FAILED THE EXAM", {
        fontSize: "56px",
        color: COLORS.text,
        fontStyle: "bold",
      })
      .setOrigin(0.5);

    this.add
      .text(GAME_WIDTH / 2, GAME_HEIGHT / 2 + 30, `You collected ${this.finalScore} ECTS`, {
        fontSize: "28px",
        color: "#c8d3e6",
      })
      .setOrigin(0.5);

    this.add
      .text(GAME_WIDTH / 2, GAME_HEIGHT - 80, "Press SPACE or tap to retry", {
        fontSize: "24px",
        color: COLORS.text,
      })
      .setOrigin(0.5);

    const retry = (): void => {
      this.scene.start(SCENES.game);
    };
    this.input.keyboard?.once("keydown-SPACE", retry);
    this.input.once("pointerdown", retry);
  }
}
