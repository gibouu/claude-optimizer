# Two Closes — one OPEN, one CLOSED. Gate must check ALL refs and block on
# the closed one.
export PR_PREFLIGHT_TEST_LINES=200
export PR_PREFLIGHT_TEST_FILES=3
export PR_PREFLIGHT_ISSUE_STATES="20:OPEN,42:CLOSED"
