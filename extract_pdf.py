import pdfplumber

pdf_path = r'c:\Users\carlo\Documents\idetect\ETO LATEST!! Updated IDETECT Final Manuscript  (1).pdf'
with pdfplumber.open(pdf_path) as pdf:
    text = ''
    for i, page in enumerate(pdf.pages):
        page_text = page.extract_text()
        if page_text:
            text += f'\n--- PAGE {i+1} ---\n' + page_text

# Save to file for easier processing
with open(r'c:\Users\carlo\Documents\idetect\manuscript_text.txt', 'w', encoding='utf-8') as f:
    f.write(text)

print(f"Extracted {len(text)} characters from PDF")
print(f"Total pages: {len(pdf.pages)}")
