"""Build and validate OCI artifacts with the exact source labels and attestations."""
import json
import subprocess
from contextlib import nullcontext
from pathlib import Path
import re
from urllib.parse import urlsplit
from tools.verify.oci.verify_oci import verify
from .layer_cache import LayerCache, namespace
from .oci_import import oci_root_identity
from tools.release.bundle.manifest import require


def web_build_arguments(environment):
    flag = environment.get("VITE_RNNOISE_ENABLED", "true")
    if flag not in ("true", "false"):
        raise ValueError("VITE_RNNOISE_ENABLED must be true or false")
    descriptor = environment.get("VITE_SCREEN_SHARE_DESCRIPTOR_V1", "true")
    if descriptor not in ("true", "false"):
        raise ValueError("VITE_SCREEN_SHARE_DESCRIPTOR_V1 must be true or false")
    simulcast = environment.get("VITE_SCREEN_SHARE_BOUNDED_SIMULCAST", "false")
    if simulcast not in ("true", "false"):
        raise ValueError("VITE_SCREEN_SHARE_BOUNDED_SIMULCAST must be true or false")
    value = environment.get("VITE_PUBLIC_ORIGIN", "").strip()
    try:
        origin = urlsplit(value)
        port = origin.port
    except ValueError as error:
        raise ValueError("VITE_PUBLIC_ORIGIN must be a valid HTTPS origin") from error
    host = (origin.hostname or "").lower()
    if (origin.scheme.lower() != "https" or not host or origin.username or origin.password
            or port == 0 or origin.path not in ("", "/") or origin.query or origin.fragment):
        raise ValueError("VITE_PUBLIC_ORIGIN must be an HTTPS origin without credentials or a path")
    authority = f"[{host}]" if ":" in host else host
    if port and port != 443:
        authority += f":{port}"
    return ["--build-arg", "VITE_RNNOISE_ENABLED=" + flag,
            "--build-arg", "VITE_SCREEN_SHARE_DESCRIPTOR_V1=" + descriptor,
            "--build-arg", "VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=" + simulcast,
            "--build-arg", "VITE_PUBLIC_ORIGIN=https://" + authority]


def _cache_import_arguments(arguments):
    result = []
    index = 0
    while index < len(arguments):
        option = arguments[index]
        if option not in ("--cache-from", "--cache-to") or index + 1 >= len(arguments):
            raise ValueError("Invalid Buildx cache arguments")
        if option == "--cache-from":
            result.extend(arguments[index:index + 2])
        index += 2
    return result


def build(source, output, revision, source_hash, environment, *, metrics=None):
    receipts = {}
    owner=environment.get('BOOHTACORD_BUILD_OWNER')
    require(owner is None or isinstance(owner,str) and re.fullmatch('[0-9a-f]{32}',owner), 'Invalid builder owner')
    measure=metrics.stage if metrics else lambda _:nullcontext()
    cache_root=environment.get('BOOHTACORD_SERVER_CACHE_ROOT')
    with (LayerCache(Path(cache_root)) if cache_root else nullcontext(None)) as cache:
        for service, context in (("api", "backend"), ("web", ".")):
            key=namespace(source,service)
            with measure(service+'_cache_prepare'):
                cache_args=cache.arguments(service,key) if cache else []
                if metrics and cache:metrics.value['cache']=cache.report
            tag = f"voice-platform-{service}:{revision}"
            archive = output / (service + ".oci.tar")
            docker_archive = output / (service + ".docker.tar")
            build_args = ["docker", "buildx", "build", "--platform", "linux/amd64",
                          "--label", f"org.opencontainers.image.revision={revision}",
                          "--label", f"org.voice-platform.source-archive-sha256={source_hash}",
                          *(['--label','org.boohtacord.builder.owner='+owner] if owner else []),
                          "--tag", tag, '--build-arg', 'BOOHTACORD_CACHE_SCOPE='+key,
                          *( ["--file", str(source / "clients/web/Dockerfile"), *web_build_arguments(environment),
                              "--build-arg", "SOURCE_REVISION=" + revision] if service == "web" else [])]
            with measure(service+'_oci_build_export'):
                subprocess.run([*build_args, "--sbom=true", "--provenance=mode=max,version=v0.2",
                                "--output", f"type=oci,dest={archive}", *cache_args, str(source / context)],
                               env=environment, check=True)
            with measure(service+'_oci_verify'):
                index_digest = oci_root_identity(archive)
                verify(archive, revision, source_hash, index_digest)
            with measure(service+'_docker_build_export'):
                subprocess.run([*build_args, "--sbom=false", "--provenance=false",
                                "--output", f"type=docker,name={tag},dest={docker_archive}",
                                *_cache_import_arguments(cache_args), str(source / context)], env=environment, check=True)
            with measure(service+'_docker_import'):
                subprocess.run(['docker','image','load','--input',str(docker_archive)],env=environment,check=True)
            with measure(service+'_image_identity'):
                identity = subprocess.check_output(
                    ["docker", "image", "inspect", "--format", "{{.Id}}\n{{json .RootFS.Layers}}", tag],
                    text=True, env=environment).splitlines()
                require(len(identity) == 2, 'Docker image inspection returned an invalid identity')
                image_id, rootfs_layers = identity
                receipts[service] = verify(archive, revision, source_hash, index_digest,
                                           docker_image_id=image_id, docker_rootfs_layers=json.loads(rootfs_layers))
            with measure(service+'_cache_publish'):
                if cache:cache.publish(service,key)
    return receipts
