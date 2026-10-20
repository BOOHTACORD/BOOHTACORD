"""Only complete same-source actual-job samples can support a speed claim."""
import copy
from datetime import datetime, timedelta, timezone
import unittest
from . import catalog, comparison

SOURCE = 'a' * 40
REPO = 'Egkurilov/BOOHTACORD'


def fixture():
    reference, plan = catalog.baseline(), catalog.plan()
    run = {'id':123, 'run_attempt':1, 'head_sha':SOURCE, 'path':'.github/workflows/web-ci-shadow.yaml',
           'repository':{'full_name':REPO}, 'head_repository':{'full_name':REPO}, 'event':'workflow_dispatch'}
    jobs=[];old=[];new=[]
    def stamp(seconds):
        return (datetime(2026,1,1,tzinfo=timezone.utc)+timedelta(seconds=seconds)).isoformat()
    def job(name,start,seconds):
        ident=len(jobs)+1
        jobs.append({'id':ident,'run_id':123,'run_attempt':1,'head_sha':SOURCE,'name':name,'status':'completed',
                     'conclusion':'success','runner_id':ident+100,'labels':['ubuntu-24.04'],
                     'runner_group_name':'GitHub Actions','created_at':stamp(0),
                     'started_at':stamp(start),'completed_at':stamp(start+seconds)})
    for sample in (1,2,3):
        identity={'run_id':'123','run_attempt':'1','namespace':'shadow-old-'+str(sample)}
        duration=600+10*sample
        old.append({'source_revision':SOURCE,'status':'PASS','operations':list(reference['operations']),
                    'legacy_reference_revision':reference['source_revision'],'legacy_source_sha256':reference['source_sha256'],
                    'seconds':duration-20,'execution':identity})
        job('legacy-'+str(sample),sample*1000,duration)
        durations={'fast':60,'browser-shell':200+10*sample,'browser-content':100,'browser-conversations':100,'browser-voice':180,'sfu-network':150}
        new.append({'source_revision':SOURCE,'status':'PASS','profiles':sorted(plan['profiles']),
                    'plan_sha256':catalog.digest(plan),'checked_operations':sum(map(len,plan['profiles'].values())),
                    'observed_profile_seconds':{p:t-10 for p,t in durations.items()},
                    'execution':{**identity,'namespace':'shadow-new-'+str(sample)}})
        for profile,seconds in durations.items():
            role={'sfu-network':'sfu','fast':'fast'}.get(profile,'browser ('+profile+')')
            job('profiles-'+str(sample)+' / '+role,sample*1000,seconds)
        job('profiles-'+str(sample)+' / frontend',sample*1000+max(durations.values())+5,10)
    job('compare',5000,1);jobs[-1].update(status='in_progress',conclusion=None,completed_at=None)
    return run,{'total_count':len(jobs),'jobs':jobs},{p:{'result':'success'} for p in ('legacy','profiles')},old,new


class ComparisonTests(unittest.TestCase):
    def test_actual_job_intervals_include_setup_fanin_and_expose_runner_cost(self):
        result=comparison.compare(*fixture())
        self.assertEqual(result['status'],'PASS')
        self.assertEqual(result['summary']['legacy']['critical_seconds'],{'p50':620,'p95':630})
        self.assertEqual(result['summary']['profiles']['critical_seconds'],{'p50':235,'p95':245})
        self.assertGreater(result['summary']['profiles']['runner_minutes']['p50'],result['summary']['legacy']['runner_minutes']['p50'])
        self.assertEqual(result['coverage'],{'legacy_operations':38,'profile_operations':40,'original_coverage_preserved':True})

    def test_failed_cancelled_missing_or_foreign_data_cannot_become_a_timing_pass(self):
        for change in ('needs','missing','duplicate','source','attempt','namespace','plan','operations','failed-job',
                       'foreign-job','old-attempt-job','missing-job','timestamps','driver-duration',
                       'shared-runner','wrong-platform','persistent-runner','repository'):
            run,jobs,needs,old,new=fixture()
            if change=='needs':needs['profiles']['result']='cancelled'
            if change=='missing':old.pop()
            if change=='duplicate':new.append(copy.deepcopy(new[0]))
            if change=='source':new[0]['source_revision']='b'*40
            if change=='attempt':old[0]['execution']['run_attempt']='2'
            if change=='namespace':new[0]['execution']['namespace']='other'
            if change=='plan':new[0]['plan_sha256']='b'*64
            if change=='operations':old[0]['operations'].pop()
            if change=='failed-job':jobs['jobs'][1]['conclusion']='failure'
            if change=='foreign-job':jobs['jobs'][1]['head_sha']='b'*40
            if change=='old-attempt-job':jobs['jobs'][1]['run_attempt']=2
            if change=='missing-job':jobs['jobs'].pop(1);jobs['total_count']-=1
            if change=='timestamps':jobs['jobs'][1]['completed_at']='2020-01-01T00:00:00Z'
            if change=='driver-duration':old[0]['seconds']=float('nan')
            if change=='shared-runner':jobs['jobs'][2]['runner_id']=jobs['jobs'][1]['runner_id']
            if change=='wrong-platform':jobs['jobs'][1]['labels']=['windows-2022']
            if change=='persistent-runner':jobs['jobs'][1]['runner_group_name']='Default'
            if change=='repository':run['head_repository']['full_name']='foreign/fork'
            with self.subTest(change=change),self.assertRaises(ValueError):comparison.compare(run,jobs,needs,old,new)

    def test_complete_but_slower_measurement_is_retained_without_an_optimization_pass(self):
        run,jobs,needs,old,new=fixture()
        for row in jobs['jobs']:
            if row['name'].startswith('legacy-'):
                row['completed_at']=(datetime.fromisoformat(row['started_at'])+timedelta(seconds=100)).isoformat()
        for row in old:row['seconds']=80
        self.assertEqual(comparison.compare(run,jobs,needs,old,new)['status'],'NO_GAIN')
