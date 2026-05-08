# Whole-plugin opt-out via .claude/optimizer-disabled — gate exits early.
mkdir -p "$PROJ_DIR/.claude"
touch "$PROJ_DIR/.claude/optimizer-disabled"
export PR_PREFLIGHT_TEST_LINES=500
export PR_PREFLIGHT_TEST_FILES=10
