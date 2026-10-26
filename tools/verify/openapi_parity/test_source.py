"""Native-source tests cover AST bindings and handler parameter extraction."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from . import source


class SourceTest(unittest.TestCase):
    def test_literal_handler_follows_serve_http(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'handler').mkdir()
            (root / 'handler/handler.go').write_text('package api\nfunc (h Handler) ServeHTTP(w http.ResponseWriter,r *http.Request){r.Header.Get("X-Notification-Account")}')
            route = {'path': '/api/v1/test', 'expression': 'auth.Require(sessions)(api.Handler{})', 'packages': ['handler']}
            with patch.object(source, 'ROOT', root):
                self.assertEqual((set(), {'X-Notification-Account'}), source.request_parameters(route))

    def extract(self, code):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            route_dir = root / "backend/internal/app/runtime"
            auth_dir = root / "backend/internal/identity/authenticate_session/api"
            route_dir.mkdir(parents=True)
            auth_dir.mkdir(parents=True)
            (auth_dir / "api.go").write_text("package renamed", encoding="utf-8")
            (route_dir / "routes.go").write_text(code, encoding="utf-8")
            files = [str(source.LEAF / name) for name in ("source.go", "bindings.go", "extract.go")]
            result = subprocess.run(["go", "run", *files], cwd=root, capture_output=True, text=True)
            if result.returncode:
                raise ValueError(result.stderr)
            return json.loads(result.stdout)

    def test_alias_and_handler_binding_follow_native_auth(self):
        code = '''package fixture
import auth "voice-platform/backend/internal/identity/authenticate_session/api"
func configure() {
    require := auth.Require(sessions)
    handler := require(endpoint)
    mux.Handle("GET /api/v1/test", handler)
}
'''
        self.assertTrue(source.authenticated(self.extract(code)[0]))
        self.assertFalse(source.authenticated(self.extract(code.replace("require(endpoint)", "endpoint"))[0]))

    def test_unknown_registration_expression_fails_closed(self):
        code = 'package fixture\nfunc configure() { mux.Handle(computeRoute(), endpoint) }'
        with self.assertRaisesRegex(ValueError, "unsupported route pattern"):
            self.extract(code)

    def test_composed_generation_path(self):
        code = '''package fixture
func configure() {
    generation := "/api/v1/previews/{generationID}"
    mux.Handle("PUT " + generation, endpoint)
}
'''
        result = self.extract(code)[0]
        self.assertEqual(("PUT", "/api/v1/previews/{generationID}"), (result["method"], result["path"]))

    def test_query_and_header_reads_follow_local_helpers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "handler"
            directory.mkdir()
            code = '''package fixture
func NewHandler() {
    query := incoming.URL.Query()
    query.Get("cursor")
    single(incoming, "limit")
    incoming.Header.Get("X-Guard")
}
func single(incoming *http.Request, name string) {
    value := incoming.URL.Query()[name]
}
'''
            path = directory / "handler.go"
            path.write_text(code, encoding="utf-8")
            route = {"path": "/api/v1/test", "expression": "api.NewHandler()", "packages": ["handler"]}
            with patch.object(source, "ROOT", root):
                self.assertEqual(({"cursor", "limit"}, {"X-Guard"}), source.request_parameters(route))
                path.write_text(code.replace('"cursor"', '"new_cursor"'), encoding="utf-8")
                self.assertEqual(({"new_cursor", "limit"}, {"X-Guard"}), source.request_parameters(route))


if __name__ == "__main__":
    unittest.main()
