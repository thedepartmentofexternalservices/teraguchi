#!/usr/bin/env python3
"""Exercise the real probe against pinned embedded fixtures; retain private logs."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

parser=argparse.ArgumentParser()
parser.add_argument('probe',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--hardware',action='store_true',help='Requires an authorized HEVC RExt-capable Mac')
args=parser.parse_args()
os.umask(0o077)
args.output.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[2]
source=(root/'apps/client/app/streaming/video/ffmpeg_videosamples.cpp').read_text()
fixtures={}
for name in ['k_HEVCRExt10_444IdentityGbrTestFrame','k_HEVCRExt8_444IdentityGbrTestFrame',
             'k_HEVCMain10TestFrame','k_HEVCRExt10_444TestFrame','k_h264High10_444TestFrame']:
    match=re.search(re.escape(name)+r'\[\]\s*=\s*\{([^}]+)\}',source)
    assert match,name
    path=args.output/(name+'.bin')
    path.write_bytes(bytes(int(byte,16) for byte in re.findall(r'0x([0-9a-fA-F]{2})',match[1])))
    fixtures[name]=path
identity=fixtures['k_HEVCRExt10_444IdentityGbrTestFrame']
truncated=args.output/'invalid.bin';truncated.write_bytes(b'not a video')
changed=args.output/'changed-format.hevc'
changed.write_bytes(identity.read_bytes()+fixtures['k_HEVCRExt8_444IdentityGbrTestFrame'].read_bytes())
profile='hevc-rext10-444-identity'
# Each expected failure must exit deliberately; crashes/signals/timeouts do not pass.
cases=[
    ('identity','software',identity,profile,1280,720,1,0,None),
    ('h264-comparison','software',fixtures['k_h264High10_444TestFrame'],'h264-44410-identity',1280,720,1,0,None),
    ('eight-bit','software',fixtures['k_HEVCRExt8_444IdentityGbrTestFrame'],profile,1280,720,1,7,'bit_depth'),
    ('wrong-profile','software',fixtures['k_HEVCMain10TestFrame'],profile,1280,720,1,7,'profile'),
    ('wrong-matrix','software',fixtures['k_HEVCRExt10_444TestFrame'],profile,1280,720,1,7,'matrix'),
    ('wrong-codec','software',identity,'h264-44410-identity',1280,720,1,7,'codec'),
    ('wrong-width','software',identity,profile,1920,720,1,7,'dimensions'),
    ('wrong-height','software',identity,profile,1280,1080,1,7,'dimensions'),
    ('missing-frame','software',identity,profile,1280,720,2,7,'frame_count'),
    ('extra-frame','software',args.output/'two-frames.hevc',profile,1280,720,1,7,'frame_count'),
    ('format-change','software',changed,profile,1280,720,2,7,'bit_depth'),
    ('invalid-input','software',truncated,profile,1280,720,1,7,'input'),
    ('unknown-profile','software',identity,'unknown',1280,720,1,2,None),
    ('zero-count','software',identity,profile,1280,720,0,2,None),
    ('malformed-count','software',identity,profile,1280,720,'1x',2,None),
]
(args.output/'two-frames.hevc').write_bytes(identity.read_bytes()*2)
if args.hardware:
    cases += [
        ('hardware-identity','hardware',identity,profile,1280,720,1,0,None),
        ('hardware-eight-bit','hardware',fixtures['k_HEVCRExt8_444IdentityGbrTestFrame'],profile,1280,720,1,7,'bit_depth'),
        ('hardware-wrong-matrix','hardware',fixtures['k_HEVCRExt10_444TestFrame'],profile,1280,720,1,7,'matrix'),
        ('hardware-h264-rejection','hardware',fixtures['k_h264High10_444TestFrame'],'h264-44410-identity',1280,720,1,7,None),
    ]
results=[]
for name,mode,path,wanted,width,height,frames,status,reason in cases:
    result=subprocess.run([str(args.probe),mode,str(path),wanted,str(width),str(height),str(frames)],
                          capture_output=True,text=True,timeout=20)
    passed=result.returncode==status
    if status==0:
        passed=passed and 'result=PASS' in result.stdout and f'expected_profile={wanted}' in result.stdout
        if mode=='hardware':passed=passed and 'hardware_attested=true' in result.stdout
    else:
        passed=passed and 'result=PASS' not in result.stdout
        if reason:passed=passed and f'reason={reason} ' in result.stderr
    (args.output/(name+'.log')).write_text(result.stdout+result.stderr)
    results.append({'case':name,'passed':bool(passed),'exit':result.returncode,'expected_exit':status,
                    'expected_reason':reason,'summary':result.stdout.strip()})
    print(name+': '+('PASS' if passed else 'FAIL'))
(args.output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(row['passed'] for row in results) else 1)
