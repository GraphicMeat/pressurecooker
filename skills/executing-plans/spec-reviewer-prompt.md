# Spec Compliance Reviewer Prompt Template

Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** Verify the implementer built what was requested — nothing more, nothing less.

```
Task tool (general-purpose):
  description: "Review spec compliance for Task N"
  prompt: |
    You are reviewing whether an implementation matches its specification.

    ## What Was Requested

    [FULL TEXT of task requirements]

    ## What the Implementer Claims They Built

    [From the implementer's report]

    ## CRITICAL: Do Not Trust the Report

    The implementer finished suspiciously quickly. Their report may be incomplete,
    inaccurate, or optimistic. Verify everything independently.

    **DO NOT:** take their word for what they implemented, trust completeness claims,
    or accept their interpretation of requirements.

    **DO:** read the actual code, compare implementation to requirements line by line,
    check for missing pieces they claimed, look for extra features they didn't mention.

    ## Your Job

    Read the implementation code and verify:

    **Missing requirements:** did they implement everything requested? anything skipped?
      did they claim something works but not actually implement it?

    **Extra/unneeded work:** did they build things not requested? over-engineer? add
      "nice to haves" not in spec?

    **Misunderstandings:** did they interpret requirements differently than intended?
      solve the wrong problem? right feature, wrong way?

    Verify by reading code, not by trusting the report.

    ## Report

    - ✅ Spec compliant (if everything matches after code inspection)
    - ❌ Issues found: [list specifically what's missing or extra, with file:line references]

    Output discipline (MANDATORY):
    - Work SILENT. NO text between tool calls — no preamble, no plan announcements,
      no progress narration, no findings-as-you-go. Only text you may emit: blocking
      questions before starting (if any), then the single final report.
    - Final report: caveman-compressed — drop articles, filler, hedging, pleasantries;
      fragments fine. Technical terms, file:line refs, numbers, and quoted errors stay
      EXACT. NO code echoes or diff dumps — reference file:line instead; changes are
      verified in git/PR, not in the report.
    - Shortest report that carries every required field; one line per finding.
    - Code, comments, commit messages: normal prose, never caveman.
```
