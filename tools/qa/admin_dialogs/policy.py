"""Exclusive batch resource identities and bounded ownership cleanup."""
import subprocess
from tools.qa.local_features.native import verify_device
from tools.qa.client_lifecycle.services import remove_owned
IOS='153A6432-6806-4B44-927B-B8CDB75FE664'
ANDROID='emulator-5554'
PORTS=(4950,4951,4952,4990,4991)

def assigned_device(platform,device):
    if platform not in ('android','ios') or device != (ANDROID if platform=='android' else IOS):
        raise ValueError('Refusing a device outside this QA assignment')
    if platform=='android':
        name=subprocess.check_output(['adb','-s',device,'emu','avd','name'],text=True).splitlines()[0]
        if name!='BOOHTACORD_QA_API35':raise ValueError('Assigned Android AVD identity changed')
    verify_device(platform,device)

def cleanup_resources(records,owner):
    if not owner.startswith('qa295298-'):raise ValueError('Refusing foreign QA ownership')
    errors=[]
    for kind,name in list(reversed(records)):
        try:
            remove_owned(name,owner,kind)
            records.remove((kind,name))
        except Exception as error:
            errors.append({'kind':kind,'error_type':type(error).__name__})
    return errors
