"""Content-free stage distributions, with separate native and viewer windows."""
import argparse,hashlib,json,math,statistics
from .run import OUT

def number(v):return type(v)in(int,float)and math.isfinite(v)and v>=0

def counter_rates(rows,key):
 out=[]
 for a,b in zip(rows,rows[1:]):
  av,bv=a.get(key),b.get(key);start,end=a.get('at_ms'),b.get('at_ms')
  if not all(number(v)for v in (av,bv,start,end))or end<=start or bv<av:continue
  out.append((bv-av)*1000/(end-start))
 return out

def distribution(values):
 values=[v for v in values if number(v)]
 return None if not values else {'count':len(values),'min':min(values),'median':statistics.median(values),'max':max(values)}

def summarize(index):
 native=json.loads((OUT/f'healthy-{index}.json').read_text());viewer=json.loads((OUT/f'receiver-{index}.json').read_text());events=native.get('observed_native',{}).get('events',[])
 publish=next((r['at_ms']for r in events if r.get('event')=='publish_returned'),None)
 rows=[]if publish is None else[r for r in events if number(r.get('at_ms'))and publish+30000<=r['at_ms']<=publish+90000]
 capture=[r for r in rows if r.get('event')=='native_capture_sample'];layers=[l for r in rows if r.get('event')=='sender_stage_sample'for l in r.get('layers',[])if l.get('state')=='ACTIVE']
 result={'status':'PARTIAL','flow_status':native.get('status'),'index':index,'scope':'Co-hosted diagnostic prototype, not hardware or physical presentation SLO','native_window':'publish-return own monotonic +30..90 seconds, separate viewer clock; no cross-clock subtraction','capture_snapshot_count':len(capture),'accepted_capture_fps':distribution(counter_rates(capture,'accepted_frames')),'postprocessed_fps':distribution(counter_rates(capture,'postprocessed_frames')),'capture_last':capture[-1]if capture else None,'processing_p95_ms_rolling_snapshot_distribution':distribution([r.get('processing_p95_ms')for r in capture]),'encoded_fps':distribution([r.get('encoded_fps')for r in layers]),'sent_fps':distribution([r.get('sent_fps')for r in layers]),'encode_ms_per_frame':distribution([r.get('encode_ms_per_frame')for r in layers]),'average_qp_codec_dependent':distribution([r.get('average_qp_codec_dependent')for r in layers]),'encoder_implementation_reported_not_hardware':sorted(set(r['encoder_implementation_reported']for r in layers if isinstance(r.get('encoder_implementation_reported'),str))),'reported_power_efficient_not_hardware':list(set(r['power_efficient_encoder_reported_not_hardware']for r in layers if isinstance(r.get('power_efficient_encoder_reported_not_hardware'),bool))),'selected_publisher_transport':next((r['publisher_selected_transport']for r in layers if r.get('publisher_selected_transport')is not None),None),'fresh_encoder_parameters':[r for r in events if r.get('event')=='fresh_encoder_parameters'],'descriptor_final_state':next((r for r in reversed(rows)if r.get('event')=='descriptor_state'),None),'metadata_HTTP_statuses':[r for r in events if r.get('event')=='descriptor_http_response'],'receiver_decoded_p05_fps':viewer.get('measurement',{}).get('decodedP05Fps'),'receiver_presentation':viewer.get('measurement',{}).get('presentation'),'receiver_sequence':viewer.get('measurement',{}).get('sequence'),'receiver_first_frame_evidence':viewer.get('firstFrameEvidence'),'receipts_sha256':{name:hashlib.sha256((OUT/name).read_bytes()).hexdigest()for name in (f'healthy-{index}.json',f'receiver-{index}.json')}}
 return result

def main():
 p=argparse.ArgumentParser();p.add_argument('--indices',type=int,nargs='+',required=True);args=p.parse_args()
 for i in args.indices:
  if i not in range(1,21):raise ValueError('Bounded existing run index required')
  result=summarize(i);(OUT/f'stage-summary-{i}.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k]for k in ['index','flow_status','capture_snapshot_count','accepted_capture_fps','encoded_fps','sent_fps','receiver_decoded_p05_fps']}))
if __name__=='__main__':main()
