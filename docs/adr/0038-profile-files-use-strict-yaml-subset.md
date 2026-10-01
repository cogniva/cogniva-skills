# Profile files use a strict YAML subset read by our own parser

**Provenance:** Suggested by agent

`profile.yml`, `.cogniva-profile.yml` markers and standard frontmatter allow only
flat `key: value` lines and simple `- item` lists; anything else is an error
naming the file and line. We chose not to add a YAML library here, consistent
with taking no dependencies so far; that is a judgement for this case, not a
rule, and a future need that justifies a dependency should be weighed on its merits.
