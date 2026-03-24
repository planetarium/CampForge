import { z } from "zod";

const SkillSpecSchema = z.object({
  skill_id: z.string(),
  source: z.enum(["generate", "reference", "fork"]),
  ref: z.string().optional(),
  modifications: z.array(z.string()).optional(),
  spec: z
    .object({
      description: z.string(),
      workflow: z.array(z.string()),
      tools_needed: z.array(z.string()).optional(),
    })
    .optional(),
});

const LevelOverrideSchema = z.object({
  append_rules: z.array(z.string()),
});

const HeartbeatCheckSchema = z.object({
  name: z.string(),
  schedule: z.string(),
  action: z.string(),
});

const TestScenarioSchema = z.object({
  name: z.string(),
  prompt: z.string(),
  expect: z.string(),
});

const DecisionTreeSchema = z.object({
  name: z.string(),
  tree: z.array(z.string()),
});

export const DomainSpecSchema = z.object({
  domain: z.object({
    id: z.string(),
    name: z.string(),

    identity: z.object({
      role_template: z.string(),
      core_values: z.array(z.string()),
      boundaries: z.array(z.string()),
      levels: z
        .record(z.string(), LevelOverrideSchema)
        .optional(),
    }),

    curriculum: z.object({
      core: z.array(SkillSpecSchema),
      elective: z.array(SkillSpecSchema).optional(),
    }),

    knowledge: z
      .object({
        glossary: z.record(z.string(), z.string()).optional(),
        decision_trees: z.array(DecisionTreeSchema).optional(),
      })
      .optional(),

    heartbeat: z
      .object({
        checks: z.array(HeartbeatCheckSchema),
      })
      .optional(),

    test_scenarios: z.array(TestScenarioSchema).optional(),
  }),
});

export type DomainSpec = z.infer<typeof DomainSpecSchema>;
export type SkillSpec = z.infer<typeof SkillSpecSchema>;
