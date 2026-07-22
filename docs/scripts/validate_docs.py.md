# 원본 파일 문서화: `scripts/validate_docs.py`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `scripts/validate_docs.py`
- 원본 형식: `python`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 주의: 이 스크립트는 문서 기준 검증 참고용이며, 실제 저장소 구조에 맞춰 검토한 뒤 사용합니다.

````python
from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(message)


def validate_json_yaml() -> None:
    for path in ROOT.rglob('*'):
        if not path.is_file():
            continue
        if path.suffix == '.json':
            json.loads(path.read_text(encoding='utf-8'))
        elif path.suffix in {'.yaml', '.yml'}:
            yaml.safe_load(path.read_text(encoding='utf-8'))


def validate_csv() -> None:
    for path in (ROOT / 'matrices').glob('*.csv'):
        rows = list(csv.reader(path.open(encoding='utf-8-sig', newline='')))
        if not rows:
            fail(f'empty csv: {path}')
        width = len(rows[0])
        for number, row in enumerate(rows[1:], start=2):
            if len(row) != width:
                fail(f'csv width mismatch: {path}:{number}')


def validate_markdown_fences() -> None:
    for path in ROOT.rglob('*.md'):
        text = path.read_text(encoding='utf-8')
        if len(re.findall(r'^```', text, flags=re.MULTILINE)) % 2:
            fail(f'unbalanced code fence: {path}')


def validate_manifest() -> None:
    path = ROOT / 'docs_manifest.json'
    if not path.exists():
        return
    data = json.loads(path.read_text(encoding='utf-8'))
    for item in data['files']:
        target = ROOT / item['path']
        if not target.exists():
            fail(f'missing manifest file: {target}')
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if digest != item['sha256']:
            fail(f'hash mismatch: {target}')


if __name__ == '__main__':
    validate_json_yaml()
    validate_csv()
    validate_markdown_fences()
    validate_manifest()
    print('KinFlow documentation validation passed')
````
