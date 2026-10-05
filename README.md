# AI Maze Game

A 2D arcade-style maze game inspired by classic maze-chase games, built with **Godot 4.x**. The player navigates through five progressively challenging levels, collecting items while avoiding an AI-controlled enemy.

The main focus of the project is the **enemy AI**, which combines:

- **A\* pathfinding** for maze navigation
- **Predictive movement** to anticipate the player's direction
- **Finite-state behaviour** including Chase, Ambush, Search, Frightened, Return, and Resume
- **Adaptive difficulty** that increases as the player progresses
- **Behavioural variation** to make the enemy less predictable

Power-ups temporarily reverse the relationship between the player and enemy, allowing the player to pursue and defeat the AI.

The project explores how traditional game AI techniques can be combined to create an enemy that feels dynamic, responsive, and capable of hunting the player rather than simply following them.
