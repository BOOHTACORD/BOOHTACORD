from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .run import main


class LocalActionPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name).resolve()
        directory=self.root/'.github/workflows';directory.mkdir(parents=True)
        (directory/'proof.yaml').write_text("""on: pull_request
permissions: {contents: read}
jobs:
  proof:
    runs-on: ubuntu-24.04
    steps:
      - uses: ./.github/actions/fixture
""")
        self.action=self.root/'.github/actions/fixture/action.yaml'
        self.action.parent.mkdir(parents=True)

    def verify(self):
        with patch('tools.verify.action_pins.run.ROOT',self.root),patch('sys.argv',['action-pins']),redirect_stdout(StringIO()):
            main()

    def test_mutable_transitive_action_cannot_hide_inside_a_local_composite(self):
        self.action.write_text("runs: {using: composite, steps: [{uses: 'actions/checkout@v4'}]}")
        with self.assertRaises(ValueError): self.verify()

    def test_missing_local_source_is_not_treated_as_pinned(self):
        with self.assertRaises(ValueError): self.verify()

    def test_composite_cannot_hide_secret_or_soft_failure_access(self):
        for step in ["{run: echo controlled, shell: bash, continue-on-error: 'true'}",
                     "{run: echo controlled, shell: bash, env: {KEY: '${{ secrets.SIGNING }}'}}"]:
            self.action.write_text('runs: {using: composite, steps: ['+step+']}')
            with self.subTest(step=step),self.assertRaises(ValueError): self.verify()

    def test_reviewed_composite_is_checked_as_part_of_the_repository(self):
        self.action.write_text("""runs:
  using: composite
  steps:
    - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
      with: {persist-credentials: 'false'}
""")
        self.verify()
