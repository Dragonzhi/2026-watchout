import sys, os

def docx_text(path):
    from docx import Document
    d = Document(path)
    out = []
    for p in d.paragraphs:
        t = p.text.strip()
        if t:
            out.append(t)
    for tb in d.tables:
        for row in tb.rows:
            cells = [c.text.strip().replace('\n', ' ') for c in row.cells]
            if any(cells):
                out.append(' | '.join(cells))
    return '\n'.join(out)

def pdf_text(path):
    import fitz
    doc = fitz.open(path)
    out = []
    for i, page in enumerate(doc):
        out.append('\n===== PAGE %d/%d =====\n' % (i + 1, doc.page_count))
        out.append(page.get_text('text'))
    return ''.join(out)

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    ext = os.path.splitext(src)[1].lower()
    if ext == '.docx':
        txt = docx_text(src)
    elif ext == '.pdf':
        txt = pdf_text(src)
    else:
        txt = ''
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(txt)
    print('%s -> %d chars' % (os.path.basename(src), len(txt)))
