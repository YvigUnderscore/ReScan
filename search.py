import urllib.request
import json
import re

req = urllib.request.Request(
    'https://duckduckgo.com/html/?q=site:developer.apple.com+CIFormat+RGBAh',
    headers={'User-Agent': 'Mozilla/5.0'}
)
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    snippets = re.findall(r'<a class="result__snippet[^>]*>(.*?)</a>', html, re.IGNORECASE | re.DOTALL)
    for snip in snippets:
        print(re.sub(r'<[^>]+>', '', snip))
except Exception as e:
    print(e)
