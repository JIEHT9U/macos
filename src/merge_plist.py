#!/usr/bin/env python3
"""
Merge Kernel->Patch array from a patch plist into a base config.plist.
Usage: merge_plist.py /path/to/base.plist /path/to/patch.plist
If Kernel or Patch keys don't exist in base, they will be created.
Existing patch entries are appended; duplicates are not checked.
"""
import sys
import plistlib
from pathlib import Path


def load_plist(path: Path):
    with path.open('rb') as f:
        return plistlib.load(f)


def save_plist(obj, path: Path):
    with path.open('wb') as f:
        plistlib.dump(obj, f)


def ensure_kernel_patch_structure(plist_obj):
    if 'Kernel' not in plist_obj or not isinstance(plist_obj['Kernel'], dict):
        plist_obj['Kernel'] = {}
    kernel = plist_obj['Kernel']
    if 'Patch' not in kernel or not isinstance(kernel['Patch'], list):
        kernel['Patch'] = []
    return kernel['Patch']


def main():
    if len(sys.argv) != 3:
        print('Usage: merge_plist.py base.plist patch.plist', file=sys.stderr)
        sys.exit(2)

    base_path = Path(sys.argv[1])
    patch_path = Path(sys.argv[2])

    if not base_path.exists():
        print(f'Base plist {base_path} not found', file=sys.stderr)
        sys.exit(3)
    if not patch_path.exists():
        print(f'Patch plist {patch_path} not found', file=sys.stderr)
        sys.exit(4)

    base = load_plist(base_path)
    patch = load_plist(patch_path)

    base_patch_array = ensure_kernel_patch_structure(base)
    patch_array = []
    if isinstance(patch, dict) and 'Kernel' in patch and isinstance(patch['Kernel'], dict):
        k = patch['Kernel']
        if 'Patch' in k and isinstance(k['Patch'], list):
            patch_array = k['Patch']

    if not patch_array:
        print('No Kernel->Patch entries found in patch plist; nothing to do')
        sys.exit(0)

    # Append patch entries
    base_patch_array.extend(patch_array)

    # Save atomically
    tmp = base_path.with_suffix('.plist.tmp')
    save_plist(base, tmp)
    tmp.replace(base_path)
    print(f'Merged {len(patch_array)} patch entries into {base_path}')


if __name__ == '__main__':
    main()
