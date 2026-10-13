"""Bounded process-only CPU cumulative time/RSS, with no command-line export."""
import re,subprocess

def parse_resource_fields(value):
 parts=value.split()
 if len(parts)!=2 or not parts[1].isdigit():return None
 match=re.fullmatch(r'(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+(?:\.\d+)?)',parts[0])
 if match is None:return None
 days,hours,minutes,seconds=match.groups()
 return {'cpu_seconds':int(days or 0)*86400+int(hours or 0)*3600+int(minutes)*60+float(seconds),'rss_bytes':int(parts[1])*1024}

def read_resources(pid):
 result=subprocess.run(['ps','-p',str(pid),'-o','time=,rss='],capture_output=True,text=True)
 return parse_resource_fields(result.stdout) if result.returncode==0 else None
