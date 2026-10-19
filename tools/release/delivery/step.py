"""Run only fixed metadata/download operations with finite deadlines and safe errors."""
import sys
from .commands import execute, ExecutionFailed

OPERATIONS = {'controller': ('consumer', (), 30), 'producer': ('authority', ('prepare',), 180),
              'download': ('download', (), 330), 'recheck': ('authority', ('recheck',), 180)}


def main():
    if len(sys.argv)!=2 or sys.argv[1] not in OPERATIONS:
        raise SystemExit('Unknown bounded delivery operation')
    name=sys.argv[1]; module,args,limit=OPERATIONS[name]
    try: execute([sys.executable,'-m','tools.release.delivery.'+module,*args],limit)
    except ExecutionFailed as error:
        raise SystemExit('Delivery operation failed: '+name+' ('+error.code+')') from None
    print('Verified delivery operation: '+name)


if __name__=='__main__': main()
