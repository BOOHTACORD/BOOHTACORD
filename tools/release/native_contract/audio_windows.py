"""Reject Windows distributions missing either production audio engine."""
import hashlib
import json
from .source import require
from tools.ci.native.process import ROOT


def verify(archive):
    lock = json.loads((ROOT / 'tools/audio/release_source/lock.json').read_text(encoding='utf-8'))
    require(json.loads(archive.read('rnnoise-engine.json')) == lock)
    require(hashlib.sha256(archive.read('LICENSE-RNNoise-0.2.txt')).hexdigest() == lock['files']['COPYING'])
    info = json.loads(archive.read('deepfilter-engine.json'))
    require(info['scope'] == 'production' and info['version'] == 'DeepFilterNet3'
            and info['sourceCommit'] == '7b14b895fe7fc42cab72b4a4c1e49c982bd6404b'
            and info['panic'] == 'unwind' and info['allocationCounter'] is False)
    for name, expected in [('boohta_deepfilter.dll', info['dllSha256']),
                           ('boohta_deepfilter_model.tar.gz', 'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616'),
                           ('licenses/deepfilter/index.json', info['noticeIndexSha256'])]:
        require(hashlib.sha256(archive.read(name)).hexdigest() == expected)
    notices = json.loads(archive.read('licenses/deepfilter/index.json'))
    require(notices['packages'] == len(notices['entries']) > 0 and notices['unresolved'] == [])
    for package in notices['entries']:
        for name, expected in package['notices'].items():
            require(hashlib.sha256(archive.read('licenses/deepfilter/' + package['package'] + '/' + name)).hexdigest() == expected)
