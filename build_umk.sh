#!/bin/bash
set -e

SRC="$HOME/УМК"
PROJ="$HOME/umk-site"
OUT="$PROJ/docs"
TMP_DOC="$HOME/.umk_doc_tmp"

rm -rf "$OUT"
mkdir -p "$OUT/stylesheets"
rm -rf "$TMP_DOC"; mkdir -p "$TMP_DOC"

# ---------- 1. .doc -> .docx ----------
echo ">>> [1/5] .doc -> .docx"
find "$SRC" -type f -name '*.doc' ! -name '~$*' | while read -r f; do
    rel="${f#$SRC/}"
    mkdir -p "$TMP_DOC/$(dirname "$rel")"
    libreoffice --headless --convert-to docx \
        --outdir "$TMP_DOC/$(dirname "$rel")" "$f" >/dev/null 2>&1 \
        || echo "  [skip] $rel"
done

# ---------- 2. .docx -> .md ----------
echo ">>> [2/5] .docx -> .md"
convert_one() {
    local src="$1" rel="$2"
    local out="$OUT/${rel%.docx}.md"
    mkdir -p "$(dirname "$out")"
    pandoc "$src" -o "$out" \
        --wrap=preserve \
        --markdown-headings=atx \
        --extract-media="$(dirname "$out")/media" \
        -t gfm \
        2>/dev/null || echo "  [fail] $rel"
    # добавляем заголовок H1 из имени файла, если его нет
    if ! grep -q '^# ' "$out"; then
        base=$(basename "${rel%.docx}")
        printf '# %s\n\n' "$base" | cat - "$out" > "$out.tmp" && mv "$out.tmp" "$out"
    fi
}

find "$SRC" -type f -name '*.docx' ! -name '~$*' | while read -r f; do
    convert_one "$f" "${f#$SRC/}"
done

find "$TMP_DOC" -type f -name '*.docx' | while read -r f; do
    convert_one "$f" "${f#$TMP_DOC/}"
done

# ---------- 3. PDF копируем как есть ----------
echo ">>> [3/5] Копирую PDF"
find "$SRC" -type f -name '*.pdf' | while read -r f; do
    rel="${f#$SRC/}"
    dest="$OUT/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$f" "$dest"
done

# ---------- 4. Ссылки на PDF внутри .md ----------
echo ">>> [4/5] Прикрепляю ссылки на PDF"
find "$OUT" -name '*.md' | while read -r md; do
    dir=$(dirname "$md")
    pdfs=$(find "$dir" -maxdepth 1 -name '*.pdf' -printf '%f\n' | sort)
    if [ -n "$pdfs" ]; then
        {
            echo ""
            echo "---"
            echo ""
            echo "## 📎 Прикреплённые файлы"
            echo ""
            echo "$pdfs" | while read -r p; do
                enc=$(python -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$p")
                echo "- 📄 [$p]($enc){ .pdf-link }"
            done
        } >> "$md"
    fi
done

# ---------- 5. index.md из "Содержание УМК" ----------
echo ">>> [5/5] Главная страница"
if [ -f "$OUT/Содержание УМК.md" ]; then
    cp "$OUT/Содержание УМК.md" "$OUT/index.md"
else
    cat > "$OUT/index.md" <<EOF
# УМК по физической культуре

Добро пожаловать. Используйте меню слева или поиск сверху.
EOF
fi

echo ">>> Готово."
echo ">>>   .md : $(find "$OUT" -name '*.md' | wc -l)"
echo ">>>   .pdf: $(find "$OUT" -name '*.pdf' | wc -l)"
