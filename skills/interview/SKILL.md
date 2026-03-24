---
name: campforge-interview
description: >
  Interactive camp creation via guided interview.
  Ask the user questions to build a domain-spec.yaml,
  then run campforge create to scaffold the camp.
  Trigger: "새 부트캠프 만들어줘", "create a new camp",
  "campforge interview", "부트캠프 인터뷰"
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires campforge CLI (npx tsx cli/bin/campforge.ts or campforge)
---

# CampForge Interview Skill

Guide the user through creating a new agent camp via conversation.
Collect answers, generate a `domain-spec.yaml`, then run `campforge create`.

## Interview Flow

### Phase 1: Domain Basics

Ask these in order. Skip if user already provided in initial request.

1. **Domain ID**
   > "부트캠프의 ID를 정해주세요 (예: devops-sre, arena-ops, iap-manager)"

   Rules: lowercase, kebab-case, no spaces.

2. **Domain Name**
   > "이 도메인의 전체 이름은? (예: DevOps / Site Reliability Engineering)"

3. **Role Description**
   > "이 에이전트는 어떤 역할을 하나요? 한두 문장으로 설명해주세요."

   This becomes `identity.role_template`. Insert `{level}` placeholder for persona level.

### Phase 2: Identity

4. **Core Values** (3-5개)
   > "이 에이전트의 핵심 가치를 3-5개 알려주세요."
   > 예시: "정확성 우선", "안전 먼저", "자동화 지향"

5. **Boundaries** (2-4개)
   > "이 에이전트가 절대 하면 안 되는 것은?"
   > 예시: "프로덕션 변경 전 반드시 확인", "파괴적 명령 금지"

6. **Persona Level**
   > "기본 페르소나 레벨은? (junior / mid / senior / lead)"

   Default: senior

7. **Language**
   > "기본 언어는? (ko / en)"

   Default: ko

### Phase 3: Skills (Curriculum)

8. **Core Skills**
   > "이 에이전트가 반드시 할 수 있어야 하는 skill을 나열해주세요."

   For each skill, ask:
   > "이 skill의 설명과 워크플로우 단계를 알려주세요."

   Collect: `skill_id`, `description`, `workflow` steps, `tools_needed`

9. **Elective Skills** (optional)
   > "선택적으로 추가할 수 있는 skill이 있나요? 없으면 스킵."

### Phase 4: Knowledge (optional)

10. **Glossary**
    > "도메인 용어 정리가 필요한가요? 있으면 용어: 정의 형태로 알려주세요. 없으면 스킵."

11. **Decision Trees** (optional)
    > "에이전트가 따를 의사결정 트리가 있나요? 없으면 스킵."

### Phase 5: Testing

12. **Test Scenarios** (1-2개)
    > "에이전트를 테스트할 프롬프트 예시를 1-2개 주세요."

    Collect: `name`, `prompt`, `expect`

### Phase 6: Confirmation & Generation

13. Show the user a summary of collected answers.
14. Ask: "이대로 부트캠프를 생성할까요?"
15. If confirmed, proceed to generation.

## Generation

After interview is complete:

1. Write the collected data as `domain-spec.yaml`:

```yaml
domain:
  id: "{domain_id}"
  name: "{domain_name}"

  identity:
    role_template: "{role_description}"
    core_values:
      - "{value_1}"
      - "{value_2}"
    boundaries:
      - "{boundary_1}"
      - "{boundary_2}"

  curriculum:
    core:
      - skill_id: "{skill_id}"
        source: "generate"
        spec:
          description: "{description}"
          workflow:
            - "{step_1}"
            - "{step_2}"
          tools_needed: ["{tool_1}"]

  knowledge:
    glossary:
      "{term}": "{definition}"

  test_scenarios:
    - name: "{test_name}"
      prompt: "{test_prompt}"
      expect: "{test_expect}"
```

2. Run campforge CLI:

```bash
campforge create --from domain-spec.yaml --persona {persona} --language {language} --output campforge-{domain_id}
```

If `campforge` is not in PATH, use:
```bash
npx tsx {campforge_cli_path}/bin/campforge.ts create --from domain-spec.yaml --persona {persona} --language {language}
```

3. After scaffold creation, offer to fill in the generated SKILL.md placeholders:
   > "스캐폴드가 생성되었습니다. 생성된 SKILL.md 파일들을 채워드릴까요?"

4. If yes, read each `skills/*/SKILL.md` that contains "TODO" and rewrite with proper content based on the interview answers.

## Rules

- Ask one question group at a time, not all at once
- Accept free-form answers and structure them yourself
- If the user says "스킵" or "skip", use sensible defaults or omit the section
- Infer `skill_id` from the description if user doesn't provide one (lowercase, kebab-case)
- Infer `tools_needed` from workflow steps if obvious (e.g. "kubectl" if workflow mentions k8s)
- Keep the conversation concise — don't repeat back everything, just confirm and move on
- The interview should take 3-5 minutes, not 15
