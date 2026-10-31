"""The exact protected auto/manual bindings and shared credential-bearing path."""
from .selection import require

ACTION = './.github/actions/install-trusted-server'
IDS = ('controller','producer','download','recheck','ssh','install','receipt','upload')


def check(workflows, action):
    for name,mode,run_id,revision in (
            ('deploy-production.yaml','automatic','${{ github.event.workflow_run.id }}',None),
            ('install-retained-release.yaml','retained','${{ inputs.build_run_id }}','${{ inputs.revision }}')):
        job=workflows[name]['jobs']['install']; steps=job.get('steps',[])
        require(job.get('timeout-minutes')=='50' and len(steps)==4,'One bounded shared install path is required')
        require(steps[0].get('uses')=='actions/checkout@v7' and steps[0].get('with')=={
            'persist-credentials':'false','fetch-depth':'0'},'Only the current controller may be checked out')
        require(steps[1].get('uses')=='actions/setup-python@v7' and steps[1].get('with')=={
            'python-version':"${{ runner.os == 'Linux' && '3.12.15' || '3.12.10' }}"}
            and steps[2].get('run')=='python -m tools.ci.toolchains.runtime python', 'Pinned selected Python is required')
        expected={'mode':mode,'build-run-id':run_id,'github-token':'${{ secrets.GITHUB_TOKEN }}',
                  'ssh-private-key':'${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}'}
        if revision is not None: expected['revision']=revision
        require(steps[3].get('uses')==ACTION and steps[3].get('with')==expected,'Event/dispatch inputs must bind the shared installer exactly')
        for step in steps:
            require(step.get('if') is None and step.get('continue-on-error') is None
                    and step.get('env') is None and step.get('working-directory') is None,'Shared install stages cannot be skipped or redirected')
    require(set(action.get('inputs',{}))=={'mode','build-run-id','revision','github-token','ssh-private-key'}
            and action.get('runs',{}).get('using')=='composite','Shared action authority inputs differ')
    steps=action['runs'].get('steps',[])
    require([s.get('id') for s in steps]==list(IDS),'Shared install order differs')
    authority={'BUILD_RUN_ID':'${{ inputs.build-run-id }}','REQUESTED_REVISION':'${{ inputs.revision }}'}
    token={'GITHUB_TOKEN':'${{ inputs.github-token }}'}
    environments=[{'DELIVERY_MODE':'${{ inputs.mode }}',**authority}, {**authority,**token}, token,
                  {**authority,**token},{'DEPLOY_SSH_PRIVATE_KEY':'${{ inputs.ssh-private-key }}'},
                  {'RELEASE_REVISION':'${{ steps.producer.outputs.revision }}',
                   'CONTROLLER_REVISION':'${{ steps.controller.outputs.controller_revision }}'},
                  {'STEP_'+name.upper():'${{ steps.'+name+'.outcome }}' for name in IDS[:6]}]
    commands=['python -m tools.release.delivery.step '+name for name in IDS[:4]]+[
        'timeout --signal=TERM --kill-after=5s 30s bash tools/release/ssh/configure-deploy-ssh.sh',
        'python -m tools.release.delivery.transfer','python -m tools.release.delivery.receipt']
    for index,step in enumerate(steps[:-1]):
        require(set(step)==({'id','name','shell','env','run'}|({'if'} if index==6 else set()))
                and step.get('run')==commands[index] and step.get('shell')=='bash'
                and step.get('env')==environments[index] and step.get('if')==('always()' if index==6 else None),
                'Shared install commands, credentials, outcomes or failure handling differ')
    require(steps[-1].get('uses')=='actions/upload-artifact@v7' and steps[-1].get('if')=='always()'
            and set(steps[-1])=={'id','name','if','uses','with'} and steps[-1]['with']=={
                'name':'delivery-${{ github.run_id }}-${{ github.run_attempt }}','path':'.out/delivery/receipt.json',
                'if-no-files-found':'error','retention-days':'30','compression-level':'9'},'A public deployment receipt must be retained for 30 days')
