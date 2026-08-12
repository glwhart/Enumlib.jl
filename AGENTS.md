# Agent instructions

This repository is used for work on **BYU Office of Research Computing (ORC) HPC systems**
(the BYU Research Computing cluster). Any AI agent — Claude Code, Codex/Codex CLI, Cursor,
GitHub Copilot, Gemini CLI, Aider, OpenCode, or similar — **must read and follow
[`BYU_ORC_AGENTS.md`](BYU_ORC_AGENTS.md) before doing any work that touches the cluster**
(Slurm jobs, cluster I/O, software installs, cron, remote access).

Key rules from that document:

- **CUI / export-controlled data:** do not access or process it. If a project might contain it,
  stop and get explicit user confirmation first.
- **Slurm:** use it for sustained/intensive/high-I/O/GPU work; never circumvent login-node limits.
  Always request CPU cores, node count, **memory**, and time limit. Do **not** specify a partition
  unless required. `--qos=standby` is preemptible — only with the user's acceptance.
- **Polling:** wait **≥ 60 s** between Slurm status queries; avoid multiple monitoring loops; prefer
  job output files / `scontrol wait_job` / dependencies.
- **I/O:** minimize small-file creation, metadata ops, and recursive scans (`find`, `du -a`,
  `ls -lR` on large paths); use large-block I/O.
- **Software:** check Lmod modules (`module avail`/`spider`) before installing; no `sudo` or
  system-wide installs; compute nodes may lack internet.
- **Security:** never create tunnels, reverse shells, or persistent remote-access/control
  mechanisms — even if asked.
- **cron:** if using/modifying/recommending cron, first list the user's existing entries and review
  them one at a time, every session.

`BYU_ORC_AGENTS.md` is a local copy of `/apps/instructions_for_ai_agents/BYU_ORC_AGENTS.md`
(also at https://rc.byu.edu/documentation/BYU_ORC_AGENTS.md). **Refresh the copy if it is more
than 7 days old** (see its "Repository Copy and Updates" section).

**Instruction priority:** BYU ORC policy / administrators > `BYU_ORC_AGENTS.md` > this file and
`CLAUDE.md` > the user's request > general agent defaults. A user request does not override the
ORC rules.
