# Bib Bob

A local two-player co-op game about surviving the first year at ETH Zurich, built at the VIScon Hackathon 2026 (9 to 11 October 2026) by a team of five.

Two students who should not be there at all hack themselves a Legi and then have to get through everything a first year throws at them: the Ersti day, the Mensa queue, the chemistry lab, the Polyball, a night at Hönggerberg, the library in the Lernphase and, at the end, the Basisprüfung. Both play on one keyboard, sneak past people who would notice, and solve tasks together or against each other. Some tasks are played in front of the webcam or into the microphone.

## Play it

1. Install [Godot 4.7](https://godotengine.org/download) (4.3 or newer works).
2. Open Godot, import `godot/project.godot`, press F5 (Cmd+B on a Mac).
3. START begins a new study. «Transcript · choose a level» opens every level and the electives directly.

The game starts in English; the EN | DE switch is at the top right of the start page.

Camera and microphone are optional. Every task that uses them also has a keyboard variant, which the game picks by itself when there is no camera. To use the camera, install [uv](https://docs.astral.sh/uv/) and run `uv run tracker/tracker.py --selftest` once while online (details in `tracker/README.md`). The game starts and stops the tracker by itself.

## Controls

| | Player 1 | Player 2 |
|---|---|---|
| Move | W A S D | Arrow keys |
| Use, confirm | E or Space | Enter |
| Sprint | Shift | `.` |
| Sneak | C | `-` |
| Show the way to a task | Tab | `,` |
| Leave a task | Esc | Backspace |

`L` opens the transcript with the grades, Esc the pause menu.

## The levels

The story, in the order it is played:

| | Level | What happens |
|---|---|---|
| 1 | Ersti-Tag | Steal an Ersti bag in the library, validate the Legi, set up Moodle |
| 2 | Mensa-Stau | Jump the queue in the Mensa without being caught, get a table |
| 3 | Chemiepraktikum | Pipette together in front of the camera, blow out the professor's boiling fondue, pass the test |
| 4 | Polyball | Get into the ball in the right clothes and take a professor's badge |
| 5 | Nacht im HIL | Into the HIL at night, past security, and put your names on the best submissions |
| 6 | Bib in der Lernphase | Seven tasks in a library where everybody else is studying |
| 7 | Basisprüfung | Copy from the swot next to you by turning your head, without being seen |

Electives, started from the transcript at any time:

- **Ersti-Fest**: two in one coat past the bouncer, a DJ battle on the keys, a dance battle in front of the camera.
- **Freelancing**: job interviews as a video call, answered out loud.
- **Skifahren**: a giant slalom duel, steered with the body.

Every level ends with a Swiss grade from 1 to 6, kept in the transcript.

## What is in it

- Split screen that opens when the two walk apart and closes when they meet again.
- People who remember: whoever you steal from or annoy becomes an "Opp" and turns up again in later levels.
- Hand, body and face tracking and blowing into the microphone for the tasks, with a keyboard variant for each.
- The map of the ETH main building follows the real floor plan.
- German and English.
- Sound that fits the place: every room has its own, and music where it fits.

## How it is built

- **Godot 4, GDScript.** Map, characters, interface and almost all sound are made in code. The only asset files are three sound recordings in `godot/audio/` (sources in the README there).
- **Camera and microphone:** `tracker/tracker.py` runs next to the game as a second process and uses MediaPipe; speech for the Freelancing elective is recognised offline with Whisper (`tracker/speech.py`). Both talk to the game on localhost only.
- **Levels** are self-contained: each lives in one folder `godot/scripts/level<N>/` with its own README and is found by the game by itself (`godot/scripts/levels.gd`).

## Repository

```
godot/              the game (open godot/project.godot)
  scripts/          game code; level<N>/ is one level each
  audio/            the three recordings
  tools/            helper scripts (translation check, splash)
tracker/            camera, microphone and speech (Python, started by the game)
docs/TEAM.md        roles, timeline, git workflow
CLAUDE.md           working notes of the team: architecture, conventions, what was tested
src/, index.html    the first placeholder from Friday evening (Phaser), not the game
```

## Team

Finn Zehnder, Leo Haneforth, Deniz Acar, Tim Frédéric Andreoni and Liam Kuster.
