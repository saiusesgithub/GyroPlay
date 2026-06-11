# -*- mode: python ; coding: utf-8 -*-

from importlib import metadata
from pathlib import Path

vigem_dll_path = str(metadata.distribution('vgamepad').locate_file('vgamepad/win/vigem/client/x64/ViGEmClient.dll'))
vigem_dll_destination = 'vgamepad/win/vigem/client/x64'

if not Path(vigem_dll_path).is_file():
    raise FileNotFoundError(f'Required vgamepad native DLL was not found: {vigem_dll_path}')

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[(vigem_dll_path, vigem_dll_destination)],
    datas=[],
    hiddenimports=[],
    hookspath=['hooks'],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='GyroPlay.Engine',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
