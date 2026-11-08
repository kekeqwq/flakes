---
name: pdf-reader
description: Read and check PDF content, particularly mathematics with equations and diagrams. Use for any request to teach from a PDF.
---

# PDF reader (Nix-managed)

The bundled scripts are from the pinned `eero-pi-config` repository. No virtualenv or pip install is needed. The absolute Python interpreter below contains PyMuPDF and is provisioned by Nix:

`@PDF_PYTHON@`

Use the actual directory containing this SKILL.md as `SKILL_DIR`. Run scripts as:

```
@PDF_PYTHON@ SKILL_DIR/scripts/pdf_info.py /absolute/path/to/file.pdf
@PDF_PYTHON@ SKILL_DIR/scripts/pdf_extract.py /absolute/path/to/file.pdf --pages 1-5
@PDF_PYTHON@ SKILL_DIR/scripts/pdf_search.py /absolute/path/to/file.pdf 'derivative'
@PDF_PYTHON@ SKILL_DIR/scripts/pdf_render.py /absolute/path/to/file.pdf --pages 3 --dpi 150
```

Always inspect metadata and table of contents first. For a long book, extract a structural overview and work on the relevant sections, not all pages at once. Extracted math can be corrupted: render the relevant pages to PNG and use `read` to inspect the equation or diagram directly. Cite the PDF page for claims from the book. If a claim is not on that page, do not attribute it to the book. Search the public web only for external verification, not as a substitute for the provided text. Do not create a Python venv or install packages outside Nix.
