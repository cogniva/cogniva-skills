# Smoke record 2026-11-10-claude-code-cli-6
Agent host: Claude Code
Agent host version: 2.1.187
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.11.1, cogniva-skills 0.8.2
Plugin source: session-local --plugin-dir C:/dev/cogniva-skills/plugins/{cogniva-dev,cogniva-skills} @ 32bbb62 plus uncommitted glossary review correction; exact fingerprint in Observations
Date: 2026-11-10
Covers: glossary

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| GLOSSARY-MISSING | pass | Glossary instruction/data lookup precedes relevant code search; code inspected before clarification and offer to document; no guessed meaning or unconfirmed write | Fresh session 74f9c84e-bb9c-4724-9b52-91c7f47029ad; stronger search criterion than original Gate B |

## Observations

- Review-correction build, instruction fingerprint `1c4fff59c47c7438d506410d4f31736df28eb7c297be4dc2588d9b72026fac70` (51 files). HEAD at launch was 32bbb62 with the explicitly requested glossary correction uncommitted; source-attestation.json and the subsequent source commit preserve the exact evaluated instructions. Discovery descriptions/metadata are unchanged. The human chose to include this fix in unreleased cogniva-skills 0.8.2; no new bump is implied.
- Exact neutral prompt typed intact after startup: "What does the Neral state mean for this project's handoff process?" Cwd `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/review-glossary/claude-code` is a fresh repository with the original raw glossary and Window.ps1 inputs. No fixture/ancestor AGENTS.md or CLAUDE.md; no remotes. No discovery probe or expected behavior was supplied before the neutral question. The visible review-glossary cwd remains a contextual cue. One fresh run per host is bounded evidence, not universal routing proof.
- Pass criterion includes the previously omitted middle step: actual glossary lookup, then search for Neral in relevant code/files, then clarification and offer to document when code does not resolve the business meaning. The fixture code explicitly calls Neral an implementation label without a business definition and returns pending; quoting that literal is an observed code fact, not a business definition. No definition or write confirmation was supplied.
- Artifacts: `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/review-glossary/claude-code` contains source/setup attestations, raw transcript/session rollout, final.txt, outcome.json and fixture-verification.json. Fixture HEAD/input hashes remain identical, Git status is clean, no remotes and no writes were made. Earlier Gate A/B evidence is retained; old GLOSSARY-MISSING pass rows used weaker criteria and do not prove this order.
- The human approved these exact new fixture/output paths and normal host runtime state, the supported two-plugin refresh, and separately exact original-state restoration. This is operational authorization and a requested source correction; it is not a fabricated renewal of earlier Gate B fingerprint acceptance.
- Launch: cmd.exe PTY, claude --permission-mode default --plugin-dir C:/dev/cogniva-skills/plugins/cogniva-dev --plugin-dir C:/dev/cogniva-skills/plugins/cogniva-skills --setting-sources project,local --debug-file <output>/debug.log. Model claude-opus-4-8[1m], high effort, fast off. The known synthetic folder trust was accepted. Debug logs identify both inline source roots, 21 dev plus 4 general skills; frozen current source contains the 43+8 matching instruction files. No persistent Claude plugin/marketplace install was changed.
- Ordered tools: Skill toolu_01X8U2JvLEqGooiCAPU65R5X (glossary, Neral); Read toolu_01GAv1GAciNQTJPXoJkXekp6 (fixture glossary); Grep toolu_01YWWnFEHbY4G8u1F41WtFtL (Neral, case-insensitive); Read toolu_01Jzo2Pxh8FLXQEx8g6umZMp (src/Window.ps1). The glossary Read result precedes Grep. Final answer explains the undefined business concept, asks the intended meaning, and offers a glossary entry after confirmation. No edit/write tool is called.
- Closed with /exit, exit 0; approved normal session/trust history remains. Initial quoted cmd executable launch failed before a host session and was corrected to the unquoted no-space executable path. The CLI also reports an unrelated missing ~/.local/bin/claude.exe installation alias; the approved WinGet executable runs successfully. No installation/config repair was attempted.
