#!/usr/bin/env node
import { Command } from "commander";
import { createCommand } from "../src/commands/create.js";
import { validateCommand } from "../src/commands/validate.js";
import { addSkillCommand } from "../src/commands/add-skill.js";
import { syncCommand } from "../src/commands/sync.js";

const program = new Command();

program
  .name("campforge")
  .description("Agent Camp Meta-Generator")
  .version("0.1.0");

program.addCommand(createCommand);
program.addCommand(validateCommand);
program.addCommand(addSkillCommand);
program.addCommand(syncCommand);

program.parse();
