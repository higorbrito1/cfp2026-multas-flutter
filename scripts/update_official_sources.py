#!/usr/bin/env python3
"""Check official Brazilian traffic sources and refresh the app metadata.

This script intentionally does not rewrite infractions from PDFs automatically.
It records official documents for human review before legal content is changed.
"""

import datetime as dt
import html.parser
import json
import pathlib
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "data" / "database-metadata.json"

PAGES = [
    ("Resoluções do CONTRAN", "Resoluções em vigor e alterações",
     "https://www.gov.br/transportes/pt-br/assuntos/transito/conteudo-Senatran/resolucoes-contran"),
    ("Deliberações e portarias do CONTRAN", "Deliberações e portarias",
     "https://www.gov.br/transportes/pt-br/assuntos/transito/conteudo-contran/deliberacoes-contran"),
    ("Conteúdo oficial da SENATRAN", "Legislação, portarias e publicações",
     "https://www.gov.br/transportes/pt-br/assuntos/transito/conteudo-Senatran"),
]


class LinkParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        href = dict(attrs).get("href")
        if href:
            self.links.append(href)


def fetch(url):
    request = urllib.request.Request(
        url, headers={"User-Agent": "Consulta-CTB-MBFT-source-check/1.0"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read().decode("utf-8", errors="replace")


def official_documents(page_url):
    parser = LinkParser()
    parser.feed(fetch(page_url))
    documents = set()
    for href in parser.links:
        absolute = urllib.parse.urljoin(page_url, href)
        parsed = urllib.parse.urlparse(absolute)
        if parsed.scheme not in ("http", "https"):
            continue
        if "gov.br" not in parsed.netloc:
            continue
        lower = absolute.lower()
        if any(token in lower for token in (".pdf", ".zip", "resolucao", "deliberacao", "portaria")):
            documents.add(absolute)
    return sorted(documents)


def main():
    today = dt.date.today().isoformat()
    sources = []
    for name, kind, url in PAGES:
        try:
            documents = official_documents(url)
            status = "ok"
        except Exception as error:  # Keep the workflow informative when gov.br is unavailable.
            documents = []
            status = f"erro: {type(error).__name__}"
        sources.append({
            "name": name,
            "kind": kind,
            "url": url,
            "status": status,
            "documentCount": len(documents),
            "documents": documents,
        })

    previous = {}
    if OUTPUT.exists():
        previous = json.loads(OUTPUT.read_text(encoding="utf-8"))
    metadata = {
        "schemaVersion": 1,
        "baseVersion": previous.get("baseVersion", "mbft-2022"),
        "baseUpdatedAt": previous.get("baseUpdatedAt", today),
        "lastOfficialCheck": today,
        "officialSources": sources,
        "reviewRequired": True,
        "reviewNote": "Novos documentos oficiais devem ser revisados antes de alterar a base de infrações.",
    }
    OUTPUT.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")


if __name__ == "__main__":
    main()
