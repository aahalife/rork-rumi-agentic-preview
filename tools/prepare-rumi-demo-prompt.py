"""Download the supplied demo prompt and decode the text-only RTF export.
No provider credentials or clinical service are accessed.
"""
from pathlib import Path
import re
import urllib.request

url = 'https://r2-pub.rork.com/attachments/7pbqhykso9l7icjsyoswc.rtf'
raw = urllib.request.urlopen(url).read().decode('utf-8')
# The supplied Cocoa RTF uses uc0 and Unicode code points for line breaks.
start = raw.index('RUMI: CHARACTER')
text = raw[start:]
text = re.sub(r"\\'([0-9a-fA-F]{2})", lambda m: bytes.fromhex(m[1]).decode('cp1252'), text)
text = re.sub(r'\\u(-?\d+) ?', lambda m: chr(int(m[1]) % 65536), text)
text = re.sub(r'\\(?:par|line)\b ?', '\n', text)
text = text.replace('\\{', '\x01').replace('\\}', '\x02')
text = re.sub(r'\\[a-zA-Z]+-?\d* ?', '', text)
text = text.replace('{', '').replace('}', '').replace('\x01', '{').replace('\x02', '}')
text = text.replace('\u2028', '\n').strip().rstrip('\\').rstrip()
assert '### 17. Openings and endings' in text
assert '{{capabilities}}' in text
out = Path(__file__).resolve().parents[1] / 'ios-rumi/Rumi/DemoAgentPrompt.txt'
out.write_text(text + '\n')
print(f'Prepared {len(text)} characters in {out.name}')
print(text[-7500:])
