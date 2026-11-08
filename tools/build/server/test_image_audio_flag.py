import unittest
import re
import shlex
from pathlib import Path
from .images import web_build_arguments


class WebAudioFlagTests(unittest.TestCase):
    origin = {'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru'}

    def test_release_passes_audio_flag_and_social_origin(self):
        self.assertEqual(web_build_arguments(self.origin), [
            '--build-arg', 'VITE_RNNOISE_ENABLED=true',
            '--build-arg', 'VITE_SCREEN_SHARE_DESCRIPTOR_V1=true',
            '--build-arg', 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=false',
            '--build-arg', 'VITE_PUBLIC_ORIGIN=https://v.bootybay.ru',
        ])
        self.assertEqual(web_build_arguments({**self.origin, 'VITE_RNNOISE_ENABLED': 'false'}), [
            '--build-arg', 'VITE_RNNOISE_ENABLED=false',
            '--build-arg', 'VITE_SCREEN_SHARE_DESCRIPTOR_V1=true',
            '--build-arg', 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=false',
            '--build-arg', 'VITE_PUBLIC_ORIGIN=https://v.bootybay.ru',
        ])
        self.assertEqual(web_build_arguments({**self.origin, 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST': 'true'}), [
            '--build-arg', 'VITE_RNNOISE_ENABLED=true',
            '--build-arg', 'VITE_SCREEN_SHARE_DESCRIPTOR_V1=true',
            '--build-arg', 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=true',
            '--build-arg', 'VITE_PUBLIC_ORIGIN=https://v.bootybay.ru',
        ])
        self.assertEqual(web_build_arguments({**self.origin, 'VITE_SCREEN_SHARE_DESCRIPTOR_V1': 'false'}), [
            '--build-arg', 'VITE_RNNOISE_ENABLED=true',
            '--build-arg', 'VITE_SCREEN_SHARE_DESCRIPTOR_V1=false',
            '--build-arg', 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=false',
            '--build-arg', 'VITE_PUBLIC_ORIGIN=https://v.bootybay.ru',
        ])

    def test_invalid_audio_flag_fails_instead_of_enabling_silently(self):
        with self.assertRaises(ValueError): web_build_arguments({**self.origin, 'VITE_RNNOISE_ENABLED': 'yes'})
        with self.assertRaises(ValueError): web_build_arguments({**self.origin, 'VITE_SCREEN_SHARE_DESCRIPTOR_V1': 'yes'})
        with self.assertRaises(ValueError):
            web_build_arguments({**self.origin, 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST': 'yes'})

    def test_invalid_public_origin_is_rejected(self):
        invalid = ({}, {'VITE_PUBLIC_ORIGIN': 'http://v.bootybay.ru'},
                   {'VITE_PUBLIC_ORIGIN': 'https://u:p@v.bootybay.ru'},
                   {'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru/path'},
                   {'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru/?q=x'},
                   {'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru/#x'})
        for environment in invalid:
            with self.subTest(environment=environment), self.assertRaises(ValueError):
                web_build_arguments(environment)

    def test_web_dockerfile_uses_repository_root_context_and_origin(self):
        root = Path(__file__).resolve().parents[3]
        source = (root / 'clients/web/Dockerfile').read_text(encoding='utf-8')
        self.assertIn('ARG VITE_PUBLIC_ORIGIN', source)
        self.assertIn('ENV VITE_PUBLIC_ORIGIN=${VITE_PUBLIC_ORIGIN}', source)
        self.assertIn('ARG VITE_SCREEN_SHARE_DESCRIPTOR_V1=true', source)
        self.assertIn('ENV VITE_SCREEN_SHARE_DESCRIPTOR_V1=${VITE_SCREEN_SHARE_DESCRIPTOR_V1}', source)
        self.assertIn('ARG VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=false', source)
        self.assertIn('ENV VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=${VITE_SCREEN_SHARE_BOUNDED_SIMULCAST}', source)
        self.assertIn('COPY clients/web/nginx.conf /etc/nginx/conf.d/default.conf', source)
        self.assertIn('COPY --from=build /app/clients/web/dist /usr/share/nginx/html', source)

    def test_web_image_includes_shared_screen_profile_catalog(self):
        root = Path(__file__).resolve().parents[3]
        source = (root / 'clients/web/Dockerfile').read_text(encoding='utf-8')
        self.assertIn(
            'COPY contracts/screen-share-profile-v1.catalog.json /app/contracts/screen-share-profile-v1.catalog.json',
            source,
        )

    def test_web_build_context_contains_shared_json_imports(self):
        root = Path(__file__).resolve().parents[3]
        dockerfile = (root / 'clients/web/Dockerfile').read_text(encoding='utf-8')
        copied = set()
        for line in dockerfile.split('RUN npm run build')[0].splitlines():
            if line.startswith('COPY '):
                copied.update(shlex.split(line)[1:-1])
        imports = set()
        for source in (root / 'clients/web/src').rglob('*'):
            if source.suffix not in ('.ts', '.vue'): continue
            for name in re.findall(r'''(?:from\s*|import\s*)['"]([^'"]+\.json)['"]''', source.read_text(encoding='utf-8')):
                target = (source.parent / name).resolve()
                if target.is_relative_to(root / 'contracts'):
                    imports.add(target.relative_to(root).as_posix())
        self.assertTrue(imports, 'No shared JSON import boundary was inspected')
        self.assertFalse(imports - copied, f'Missing shared build inputs: {sorted(imports - copied)}')
