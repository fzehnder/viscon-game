import Phaser from "phaser";
import { COLORS, GAME_HEIGHT, GAME_WIDTH, SCENES } from "../config";

const PLAYER_SPEED = 420;

// Placeholder gameplay so the whole team can see something running on hour 1.
// Replace or extend this with the real game.
export class GameScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Sprite;
  private exams!: Phaser.Physics.Arcade.Group;
  private credits!: Phaser.Physics.Arcade.Group;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private keyA!: Phaser.Input.Keyboard.Key;
  private keyD!: Phaser.Input.Keyboard.Key;
  private scoreText!: Phaser.GameObjects.Text;
  private score = 0;
  private spawnTimer = 0;

  constructor() {
    super(SCENES.game);
  }

  create(): void {
    this.score = 0;
    this.spawnTimer = 0;

    this.player = this.physics.add.sprite(GAME_WIDTH / 2, GAME_HEIGHT - 50, "player");
    this.player.setCollideWorldBounds(true);

    this.exams = this.physics.add.group();
    this.credits = this.physics.add.group();

    const keyboard = this.input.keyboard;
    if (!keyboard) throw new Error("Keyboard input not available");
    this.cursors = keyboard.createCursorKeys();
    this.keyA = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A);
    this.keyD = keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D);

    this.scoreText = this.add.text(16, 16, "ECTS: 0", {
      fontSize: "26px",
      color: COLORS.text,
    });

    this.physics.add.overlap(this.player, this.credits, (_player, credit) => {
      credit.destroy();
      this.score += 1;
      this.scoreText.setText(`ECTS: ${this.score}`);
    });

    this.physics.add.overlap(this.player, this.exams, () => {
      this.scene.start(SCENES.gameOver, { score: this.score });
    });
  }

  update(_time: number, delta: number): void {
    this.handleMovement();
    this.handleSpawning(delta);
    this.cleanup(this.exams);
    this.cleanup(this.credits);
  }

  private handleMovement(): void {
    let vx = 0;
    if (this.cursors.left.isDown || this.keyA.isDown) vx -= PLAYER_SPEED;
    if (this.cursors.right.isDown || this.keyD.isDown) vx += PLAYER_SPEED;

    const pointer = this.input.activePointer;
    if (pointer.isDown) {
      const dx = pointer.x - this.player.x;
      if (Math.abs(dx) > 10) vx = Math.sign(dx) * PLAYER_SPEED;
    }

    this.player.setVelocityX(vx);
  }

  private handleSpawning(delta: number): void {
    this.spawnTimer += delta;
    const interval = Math.max(250, 700 - this.score * 15);
    if (this.spawnTimer < interval) return;
    this.spawnTimer = 0;

    const x = Phaser.Math.Between(24, GAME_WIDTH - 24);
    if (Math.random() < 0.35) {
      const credit = this.credits.create(x, -20, "credit") as Phaser.Physics.Arcade.Sprite;
      credit.setVelocityY(Phaser.Math.Between(180, 260));
    } else {
      const exam = this.exams.create(x, -20, "exam") as Phaser.Physics.Arcade.Sprite;
      exam.setVelocityY(Phaser.Math.Between(200, 340));
    }
  }

  private cleanup(group: Phaser.Physics.Arcade.Group): void {
    for (const child of [...group.getChildren()]) {
      const sprite = child as Phaser.Physics.Arcade.Sprite;
      if (sprite.y > GAME_HEIGHT + 40) sprite.destroy();
    }
  }
}
