#!/bin/bash
## ──────────────────────────────────────────────────────────────────────────────
# 1) Create & activate a local venv in .venv (if not already present)
# ──────────────────────────────────────────────────────────────────────────────
if [[ ! -d .venv ]]; then
  echo "Creating virtualenv in .venv…"
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

# ──────────────────────────────────────────────────────────────────────────────
# 2) Install Python deps into the venv
# ──────────────────────────────────────────────────────────────────────────────
echo "Installing Python dependencies into venv…"
pip install --upgrade pip >/dev/null
pip install -r requirements.txt >/dev/null

# ──────────────────────────────────────────────────────────────────────────────
# 3) Gather data files
# ──────────────────────────────────────────────────────────────────────────────
mapfile -t files < <(find data -maxdepth 1 -type f)

# ──────────────────────────────────────────────────────────────────────────────
# 4) Load denormalized
# ──────────────────────────────────────────────────────────────────────────────
echo '================================================================================'
echo 'load denormalized'
echo '================================================================================'
time for file in "${files[@]}"; do
  echo "  → $file"
  unzip -p "$file" \
    | sed 's/\\u0000//g' \
    | psql postgresql://postgres:pass@localhost:2100 \
        -c "COPY tweets_jsonb (data) FROM STDIN CSV QUOTE E'\x01' DELIMITER E'\x02';"
done

# ──────────────────────────────────────────────────────────────────────────────
# 5) Load normalized (unbatched)
# ──────────────────────────────────────────────────────────────────────────────
echo '================================================================================'
echo 'load pg_normalized'
echo '================================================================================'
time for file in "${files[@]}"; do
  echo "  → $file"
  python3 load_tweets.py \
    --db postgresql://postgres:pass@localhost:2200 \
    --inputs "$file"
done

# ──────────────────────────────────────────────────────────────────────────────
# 6) Load normalized (batched)
# ──────────────────────────────────────────────────────────────────────────────
echo '================================================================================'
echo 'load pg_normalized_batch'
echo '================================================================================'
time for file in "${files[@]}"; do
  echo "  → $file"
  python3 -u load_tweets_batch.py \
    --db postgresql://postgres:pass@localhost:2300/ \
    --inputs "$file"
done
