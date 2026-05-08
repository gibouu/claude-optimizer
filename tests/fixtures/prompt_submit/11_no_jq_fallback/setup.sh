# Mask jq with a fake binary that always exits non-zero — forces the
# script to fall through to the sed-based prompt extractor.
JQ_MASK="$PROJ_DIR/.bin"
mkdir -p "$JQ_MASK"
cat > "$JQ_MASK/jq" <<'BASH'
#!/bin/sh
exit 1
BASH
chmod +x "$JQ_MASK/jq"
export PATH="$JQ_MASK:$PATH"
