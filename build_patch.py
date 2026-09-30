#!/usr/bin/env python3
import os
import sys
import glob
import shutil
import subprocess
import zipfile
import re

repo_dir = os.path.dirname(os.path.abspath(__file__))
java_src = os.path.join(repo_dir, 'src', 'app', 'morphe', 'extension', 'jhc', 'JhcUpdateCheckPatch.java')
mpp_file = os.path.join(repo_dir, 'update-check.mpp')
libs_dir = os.path.join(repo_dir, 'libs')
android_jar = os.path.join(libs_dir, 'android.jar')
r8_jar = os.path.join(libs_dir, 'r8.jar')

build_dir = os.path.join(repo_dir, '.build_tmp')
if os.path.exists(build_dir):
    shutil.rmtree(build_dir)
os.makedirs(build_dir)

classes_dir = os.path.join(build_dir, 'classes')
os.makedirs(classes_dir)

dex_dir = os.path.join(build_dir, 'dex')
os.makedirs(dex_dir)

print('[1/4] Compiling Java with javac...')
cmd_javac = [
    'javac',
    '-encoding', 'UTF-8',
    '-cp', android_jar,
    '-d', classes_dir,
    java_src
]
res = subprocess.run(cmd_javac, capture_output=True, text=True)
if res.stdout: print(res.stdout)
if res.stderr: print(res.stderr)
assert res.returncode == 0, f'javac failed with code {res.returncode}'

class_files = []
for root, dirs, files in os.walk(classes_dir):
    for f in files:
        if f.endswith('.class'):
            class_files.append(os.path.join(root, f))
print(f'Found {len(class_files)} compiled class files.')

print('[2/4] Running D8 to produce classes.dex...')
cmd_d8 = ['java', '-cp', r8_jar, 'com.android.tools.r8.D8', '--lib', android_jar, '--output', dex_dir] + class_files
res = subprocess.run(cmd_d8, capture_output=True, text=True)
if res.stdout: print(res.stdout)
if res.stderr: print(res.stderr)
assert res.returncode == 0, f'd8 failed with code {res.returncode}'

dex_path = os.path.join(dex_dir, 'classes.dex')
assert os.path.exists(dex_path), 'classes.dex was not generated'
print(f'classes.dex size: {os.path.getsize(dex_path)} bytes')

print(f'[3/4] Updating extensions/jhc.mpe inside {os.path.basename(mpp_file)}...')
mpp_temp = mpp_file + '.tmp'
with zipfile.ZipFile(mpp_file, 'r') as zin, zipfile.ZipFile(mpp_temp, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        if item.filename == 'extensions/jhc.mpe':
            zout.write(dex_path, 'extensions/jhc.mpe')
            print('  Replaced extensions/jhc.mpe')
        else:
            zout.writestr(item, zin.read(item.filename))

os.replace(mpp_temp, mpp_file)
shutil.rmtree(build_dir, ignore_errors=True)
print(f'[4/4] Done! Successfully updated {mpp_file}, new size: {os.path.getsize(mpp_file)} bytes')
