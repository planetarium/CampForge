import { z } from "zod";

const CompatibilityEntrySchema = z.object({
  platform: z.string(),
  version: z.string().optional(),
  status: z.enum(["pass", "partial", "fail"]),
  notes: z.string().optional(),
});

export const ManifestSchema = z.object({
  bootcamp: z.object({
    name: z.string(),
    version: z.string(),
    spec_version: z.string(),
    description: z.string(),

    domain: z.object({
      primary: z.string(),
      tags: z.array(z.string()),
    }),

    persona: z.object({
      level: z.enum(["junior", "mid", "senior", "lead"]),
      tone: z.enum(["friendly", "direct", "formal", "casual"]),
      proactivity: z.enum(["low", "medium", "high"]),
      language: z.string(),
    }),

    skills: z.object({
      required: z.array(z.string()),
      optional: z.array(z.string()).default([]),
    }),

    dependencies: z
      .object({
        tools: z.array(z.string()).default([]),
        mcp_servers: z.array(z.any()).default([]),
        skills: z.array(z.any()).default([]),
      })
      .optional(),

    compatibility: z
      .object({
        tested: z.array(CompatibilityEntrySchema).default([]),
        frontmatter_mode: z.string().optional(),
      })
      .optional(),
  }),
});

export type Manifest = z.infer<typeof ManifestSchema>;
