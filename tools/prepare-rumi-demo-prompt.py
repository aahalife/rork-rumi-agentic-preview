"""Reproduce the bundled prompt from the latest user-supplied Word document.
Only the public attachment is downloaded; no provider or clinical service is used.
"""
from io import BytesIO
from pathlib import Path
import hashlib
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

URL = 'https://r2-pub.rork.com/attachments/cu9nlqe956s802p84jfm7.docx'
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'


def extract(raw: bytes) -> str:
    with zipfile.ZipFile(BytesIO(raw)) as archive:
        document = ET.fromstring(archive.read('word/document.xml'))
    paragraphs = []
    for paragraph in document.iter(W + 'p'):
        parts = []
        for node in paragraph.iter():
            if node.tag == W + 't':
                parts.append(node.text or '')
            elif node.tag in (W + 'br', W + 'cr'):
                parts.append('\n')
            elif node.tag == W + 'tab':
                parts.append('\t')
        paragraphs.append(''.join(parts))
    text = '\n'.join(paragraphs).strip()
    for required in ('RUMI: CHARACTER', '### 17. Openings and endings',
                     '{{capabilities}}', '[RUMI CONNECTION POLICY]',
                     '[RUMI BEHAVIOR POLICY]'):
        if required not in text:
            raise ValueError(f'Prompt document missing required section: {required}')
    return text + '\n'


def main():
    with urllib.request.urlopen(URL, timeout=30) as response:
        raw = response.read(5_000_001)
    if len(raw) > 5_000_000:
        raise ValueError('Prompt document exceeds download limit')
    text = extract(raw)
    out = Path(__file__).resolve().parents[1] / 'ios-rumi/Rumi/DemoAgentPrompt.txt'
    old = out.read_text() if out.exists() else ''
    out.write_text(text)
    print(f'Prepared {len(text):,} characters in {out.name}')
    print(f'Previous prompt identical: {old == text}')
    print(f'SHA-256: {hashlib.sha256(text.encode()).hexdigest()}')


if __name__ == '__main__':
    main()
