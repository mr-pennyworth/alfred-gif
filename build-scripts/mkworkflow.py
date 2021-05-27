# -*- coding: utf-8 -*-

import os
import plistlib
import shutil
import subprocess

from contextlib import contextmanager


XCPROJ = 'alfred-gif-browser/AlfredGifBrowser.xcodeproj/project.pbxproj'
BUILD_DIR = 'wfbuild'
WF_FILES = [
  'AlfredGifBrowser.app',
  'B9741F37-05A5-4DB4-87C0-2848655113DF.png',
  'gif-downloader.bin',
  'icon.png',
  'info.plist',
  'README.md',
  'gif-browser.css',
  'gif-browser.js',
  'smoothscroll.js',
]


def copy(filenames, dest_folder):
  if os.path.exists(dest_folder):
    shutil.rmtree(dest_folder)
  os.makedirs(dest_folder)

  for filename in filenames:
    if os.path.isdir(filename):
      shutil.copytree(filename, f'{dest_folder}/{filename}')
    else:
      shutil.copy(filename, f'{dest_folder}/{filename}')


def plistRead(path):
  with open(path, 'rb') as f:
    return plistlib.load(f)


def plistWrite(obj, path):
  with open(path, 'wb') as f:
    return plistlib.dump(obj, f)


@contextmanager
def cwd(dir):
  old_wd = os.path.abspath(os.curdir)
  os.chdir(dir)
  yield
  os.chdir(old_wd)

  
def make_export_ready(plist_path, version):
  wf = plistRead(plist_path)

  # remove noexport vars
  wf['variablesdontexport'] = []

  wf['version'] = version
  with open('README.md') as f:
    wf['readme'] = f.read()

  plistWrite(wf, plist_path)
  return wf['name']


def biggest_version(*versions):
  biggest = max(
    [int(c) for c in version.split('.')]
    for version in versions
  )
  return '.'.join(str(c) for c in biggest)


def get_app_version():
  with open(XCPROJ) as f:
    for line in f.readlines():
      if 'MARKETING_VERSION' in line:
        return line.split('= ')[-1].split(';')[0]


def set_app_version(old_v, new_v):
  with open(XCPROJ) as f:
    new_content = f.read().replace(
      f'MARKETING_VERSION = {old_v}',
      f'MARKETING_VERSION = {new_v}'
    )
  with open(XCPROJ, 'w') as f:
    f.write(new_content)


def get_workflow_version():
  return plistRead('info.plist')['version']
  

if __name__ == '__main__':
  app_v = get_app_version()
  print(f'App version: {app_v}')
  wf_v = get_workflow_version()
  print(f'Workflow version: {wf_v}')
  big_v = biggest_version(app_v, wf_v)
  print(f'Syncing versions to: {big_v}')
  set_app_version(old_v=app_v, new_v=big_v)

  subprocess.call(['./build-scripts/mkapp.sh'])
  subprocess.call(['./build-scripts/mkdownloader.sh'])
  copy(WF_FILES, BUILD_DIR)
  wf_name = make_export_ready(f'{BUILD_DIR}/info.plist', big_v)
  with cwd(BUILD_DIR):
    subprocess.call(
      ['zip', '-q', '-r', f'../{wf_name}.alfredworkflow'] + WF_FILES
    )
