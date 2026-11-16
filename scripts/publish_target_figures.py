#!/usr/bin/env python3
"""Stage only small representative figures from this gated Actions run."""
from pathlib import Path
from PIL import Image

stage = Path('staging')
output = Path('figures/target-informed')
output.mkdir(parents=True, exist_ok=True)
counts = {'cwru': 0, 'paderborn': 0, 'ottawa': 0, 'xjtu': 0}
for dataset in counts:
    root = stage / f'target-informed-{dataset}'
    assert root.exists(), root
    for image in sorted(root.rglob('*.png')):
        if image.name not in {'paper_figure.png', 'candidate_spectra.png'}:
            continue
        pdf = image.with_suffix('.pdf')
        assert pdf.is_file() and pdf.read_bytes()[:5] == b'%PDF-'
        with Image.open(image) as img:
            img.verify()
        with Image.open(image) as img:
            assert img.width >= 1500 and img.height >= 1500, (image, img.size)
            print(dataset, image, img.size)
        case = image.parent.parent.name
        target = image.parent.name
        kind = 'eight-panel' if image.name == 'paper_figure.png' else 'candidate-spectra'
        stem = f'{dataset}-{case}-{target}-{kind}'
        (output / f'{stem}.png').write_bytes(image.read_bytes())
        (output / f'{stem}.pdf').write_bytes(pdf.read_bytes())
        counts[dataset] += 1
assert counts['cwru'] >= 2 and counts['paderborn'] >= 6
assert counts['ottawa'] >= 2 and counts['xjtu'] >= 3, counts
print('TARGET_FIGURE_CHECK_PASS', counts)
