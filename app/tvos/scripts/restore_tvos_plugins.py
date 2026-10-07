#!/usr/bin/env python3
"""Re-adds the tvos plugins to .flutter-plugins-dependencies.

Running the regular flutter tool (pub get, analyze, build) regenerates that
file without a tvos key, and the next pod install then drops every *_tvos pod
from the tvOS Runner. Run this before pod install / xcodebuild in tvos/.
"""
import json
import os
import sys

PACKAGES = [
    'flutter_secure_storage_tvos-0.0.1',
    'flutter_tvos-1.1.2',
    'path_provider_tvos-0.0.1',
    'shared_preferences_tvos-0.0.1',
    'sqflite_tvos-0.0.1',
]

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
registry = os.path.join(repo_root, '.flutter-plugins-dependencies')
cache = os.path.expanduser('~/.pub-cache/hosted/pub.dev')

with open(registry) as f:
    data = json.load(f)

entries = []
for pkg in PACKAGES:
    path = os.path.join(cache, pkg) + os.sep
    if not os.path.isdir(path):
        sys.exit(f'error: {path} not found; run flutter-tvos pub get first')
    entries.append({
        'name': pkg.rsplit('-', 1)[0],
        'path': path,
        'native_build': True,
        'shared_darwin_source': False,
        'dependencies': [],
        'dev_dependency': False,
    })

data['plugins']['tvos'] = entries
with open(registry, 'w') as f:
    json.dump(data, f, indent=2)
print('restored tvos plugins:', ', '.join(e['name'] for e in entries))
